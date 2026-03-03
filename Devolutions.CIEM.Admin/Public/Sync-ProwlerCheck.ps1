function Sync-ProwlerCheck {
    <#
    .SYNOPSIS
        Syncs new Prowler checks from the upstream GitHub repository.

    .DESCRIPTION
        Uses the GitHub Trees API (single cached request) to discover all checks in the
        Prowler repository, then uses git sparse checkout to bulk-download only new checks.
        This replaces per-file HTTP downloads with ~2 git round-trips regardless of check count.

        For incremental syncs with 0 new checks, this costs a single cached API call.

    .PARAMETER Provider
        Filter to specific provider(s) (azure, aws, gcp).
        Accepts one or more values. If not specified, syncs all providers defined in CIEM config.

    .PARAMETER Service
        Filter to specific service(s) (e.g., entra, iam, storage).
        Accepts one or more values.

    .PARAMETER Ref
        Branch, tag, or commit SHA to sync from. Defaults to 'master'.

    .EXAMPLE
        Sync-ProwlerCheck
        # Syncs all check files for supported providers

    .EXAMPLE
        Sync-ProwlerCheck -Provider azure -Service entra
        # Syncs only Entra-related checks

    .EXAMPLE
        Sync-ProwlerCheck -Provider azure, aws -Verbose
        # Syncs checks for both Azure and AWS providers

    .EXAMPLE
        Sync-ProwlerCheck -Ref 'v4.0.0'
        # Syncs checks from the v4.0.0 tag
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet('azure', 'aws', 'gcp')]
        [string[]]$Provider,

        [Parameter()]
        [string[]]$Service,

        [Parameter()]
        [string]$Ref = 'master'
    )

    $ErrorActionPreference = 'Stop'

    $providersToSync = if ($Provider) {
        @($Provider)
    }
    else {
        # Derive supported providers from checks registered in the SQLite checks table
        @(Get-CIEMCheck | ForEach-Object { $_.Provider.ToLower() } | Select-Object -Unique)
    }

    Write-Verbose "Syncing Prowler checks from GitHub..."
    Write-Verbose "  Providers: $($providersToSync -join ', ')"
    if ($Service) { Write-Verbose "  Services: $($Service -join ', ')" }
    Write-Verbose "  Ref: $Ref"

    # 1. Get the full repo tree (single API call, cached)
    Write-Verbose "Fetching repository tree..."
    $tree = Get-GitHubRepoTree -Owner 'prowler-cloud' -Repo 'prowler' -Ref $Ref -Path 'prowler/providers' -ErrorAction Stop

    # 2. Find check directories via regex on tree paths
    #    Pattern: prowler/providers/{provider}/services/{service}/{checkName}/{checkName}.metadata.json
    $checkEntries = $tree | Where-Object {
        $_.Type -eq 'blob' -and $_.Path -match '^prowler/providers/([^/]+)/services/([^/]+)/([^/]+)/\3\.metadata\.json$'
    }

    Write-Verbose "Found $($checkEntries.Count) total checks in repository tree"

    # 3. Apply provider and service filters
    $filteredEntries = $checkEntries | Where-Object {
        $null = $_.Path -match '^prowler/providers/([^/]+)/services/([^/]+)/([^/]+)/'
        $entryProvider = $Matches[1]
        $entryService = $Matches[2]

        $providerMatch = $entryProvider -in $providersToSync
        $serviceMatch = if ($Service) { $entryService -in $Service } else { $true }
        $providerMatch -and $serviceMatch
    }

    Write-Verbose "After filters: $($filteredEntries.Count) checks"

    # 4. Classify each check: does its DB metadata exist? Does its script file exist?
    $existingMetadata = @{}
    Get-CIEMCheckMetadata | ForEach-Object { $existingMetadata[$_.id] = $true }

    $needsMetadata = [System.Collections.Generic.List[string]]::new()
    $needsScript = [System.Collections.Generic.List[string]]::new()
    $skippedMetadata = [System.Collections.Generic.List[string]]::new()
    $skippedScripts = [System.Collections.Generic.List[string]]::new()
    $failed = [System.Collections.Generic.List[string]]::new()

    # Track which entries need sparse checkout
    $entriesToProcess = [System.Collections.Generic.List[object]]::new()

    foreach ($entry in $filteredEntries) {
        $null = $entry.Path -match '^prowler/providers/([^/]+)/services/[^/]+/([^/]+)/'
        $prov = (Get-Culture).TextInfo.ToTitleCase($Matches[1])
        $cn = $Matches[2]
        $funcName = Get-CheckFunctionName -CheckId $cn
        $checksDir = Join-Path $script:PsuAppRoot 'modules' $prov 'Checks'
        $hasScript = Test-Path (Join-Path $checksDir "$funcName.ps1")
        $hasDb = $existingMetadata.ContainsKey($cn)

        if ($hasDb) { $skippedMetadata.Add($cn) } else { $needsMetadata.Add($cn) }
        if ($hasScript) { $skippedScripts.Add($cn) } else { $needsScript.Add($cn) }

        if (-not $hasDb -or -not $hasScript) {
            $entriesToProcess.Add($entry)
        }
    }

    Write-Verbose "Metadata: $($needsMetadata.Count) new, $($skippedMetadata.Count) skipped"
    Write-Verbose "Scripts:  $($needsScript.Count) new, $($skippedScripts.Count) skipped"

    if ($entriesToProcess.Count -eq 0) {
        Write-Verbose "All checks are up to date."
        return [PSCustomObject]@{
            CreatedMetadata = @()
            CreatedScripts  = @()
            SkippedMetadata = @($skippedMetadata)
            SkippedScripts  = @($skippedScripts)
            Failed          = @($failed)
        }
    }

    # 5. Sparse checkout checks that need processing (bulk download via git)
    $sparsePaths = @()
    foreach ($p in $providersToSync) {
        if ($Service) {
            foreach ($s in $Service) {
                $sparsePaths += "prowler/providers/$p/services/$s"
            }
        } else {
            $sparsePaths += "prowler/providers/$p"
        }
    }

    $createdMetadata = [System.Collections.Generic.List[string]]::new()
    $createdScripts = [System.Collections.Generic.List[string]]::new()
    $needsMetadataSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$needsMetadata)
    $needsScriptSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$needsScript)
    $cloneDir = $null
    try {
        $cloneDir = Save-GitHubRepoSparseCheckout -Owner 'prowler-cloud' -Repo 'prowler' -Ref $Ref `
            -Paths $sparsePaths -ErrorAction Stop

        Write-Verbose "Sparse checkout complete. Processing $($entriesToProcess.Count) checks..."

        foreach ($entry in $entriesToProcess) {
            $null = $entry.Path -match '^prowler/providers/([^/]+)/services/([^/]+)/([^/]+)/'
            $providerName = $Matches[1]
            $serviceName = $Matches[2]
            $checkName = $Matches[3]

            $wantMeta = $needsMetadataSet.Contains($checkName)
            $wantScript = $needsScriptSet.Contains($checkName)
            $action = if ($wantMeta -and $wantScript) { 'metadata+script' }
                      elseif ($wantMeta) { 'metadata' }
                      else { 'script' }
            Write-Verbose "  [$action] $checkName ($providerName/$serviceName)"

            $checkDir = Join-Path $cloneDir "prowler/providers/$providerName/services/$serviceName/$checkName"

            try {
                if (-not (Test-Path $checkDir)) {
                    Write-Verbose "    Check directory not found in sparse checkout: $checkDir"
                    $failed.Add($checkName)
                    continue
                }

                # Create metadata if missing
                if ($wantMeta) {
                    Convert-ProwlerCheck -CheckPath $checkDir -MetadataOnly | Out-Null
                    $createdMetadata.Add($checkName)
                }

                # Create script if missing
                if ($wantScript) {
                    Convert-ProwlerCheck -CheckPath $checkDir -ScriptOnly | Out-Null
                    $createdScripts.Add($checkName)
                }
            }
            catch {
                Write-Verbose "    Failed: $_"
                $failed.Add($checkName)
            }
        }

        Write-Verbose "Summary: CreatedMetadata=$($createdMetadata.Count), CreatedScripts=$($createdScripts.Count), SkippedMetadata=$($skippedMetadata.Count), SkippedScripts=$($skippedScripts.Count), Failed=$($failed.Count)"

        [PSCustomObject]@{
            CreatedMetadata = @($createdMetadata)
            CreatedScripts  = @($createdScripts)
            SkippedMetadata = @($skippedMetadata)
            SkippedScripts  = @($skippedScripts)
            Failed          = @($failed)
        }
    }
    finally {
        if ($cloneDir -and (Test-Path $cloneDir)) {
            Write-Verbose "Cleaning up sparse checkout..."
            Remove-Item $cloneDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
