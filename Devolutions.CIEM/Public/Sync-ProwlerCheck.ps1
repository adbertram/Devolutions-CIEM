function Sync-ProwlerCheck {
    <#
    .SYNOPSIS
        Syncs new Prowler checks from the upstream GitHub repository.

    .DESCRIPTION
        Uses the GitHub Trees API (single cached request) to discover all checks in the
        Prowler repository, then downloads only new checks via raw.githubusercontent.com.
        Each new check requires 2 HTTP requests (metadata.json + .py file).

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
        @((Get-CIEMProvider).Name.ToLower())
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

    # 4. Diff against existing checks
    $existingChecks = @(Get-CIEMCheck)
    $existingIds = @($existingChecks | ForEach-Object { $_.Id })

    $newEntries = $filteredEntries | Where-Object {
        $null = $_.Path -match '/([^/]+)/[^/]+\.metadata\.json$'
        $checkName = $Matches[1]
        $checkName -notin $existingIds
    }

    $newEntryList = @($newEntries)
    $skippedCount = $filteredEntries.Count - $newEntryList.Count

    Write-Verbose "New checks to sync: $($newEntryList.Count), Already exist: $skippedCount"

    $success = [System.Collections.Generic.List[string]]::new()
    $failed = [System.Collections.Generic.List[string]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()

    # Build skipped list from existing checks that matched filters
    $filteredEntries | Where-Object {
        $null = $_.Path -match '/([^/]+)/[^/]+\.metadata\.json$'
        $Matches[1] -in $existingIds
    } | ForEach-Object {
        $null = $_.Path -match '/([^/]+)/[^/]+\.metadata\.json$'
        $skipped.Add($Matches[1])
    }

    if ($newEntryList.Count -eq 0) {
        Write-Verbose "No new checks to sync."
        return [PSCustomObject]@{
            Success = @($success)
            Failed  = @($failed)
            Skipped = @($skipped)
        }
    }

    # 5. Download and convert new checks
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ciem-sync-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        foreach ($entry in $newEntryList) {
            $null = $entry.Path -match '^prowler/providers/([^/]+)/services/([^/]+)/([^/]+)/'
            $providerName = $Matches[1]
            $serviceName = $Matches[2]
            $checkName = $Matches[3]

            Write-Verbose "  Syncing: $checkName ($providerName/$serviceName)"

            # Create temp directory structure that Convert-ProwlerCheck expects
            $tempCheckDir = Join-Path $tempDir "providers/$providerName/services/$serviceName/$checkName"

            try {
                # Download metadata.json (required)
                $metadataRepoPath = "prowler/providers/$providerName/services/$serviceName/$checkName/$checkName.metadata.json"
                $metadataDest = Join-Path $tempCheckDir "$checkName.metadata.json"

                Save-GitHubRepoFile -Owner 'prowler-cloud' -Repo 'prowler' -Ref $Ref `
                    -Path $metadataRepoPath -Destination $metadataDest -ErrorAction Stop

                # Download .py file (optional, used for permission inference)
                $pyRepoPath = "prowler/providers/$providerName/services/$serviceName/$checkName/$checkName.py"
                $pyDest = Join-Path $tempCheckDir "$checkName.py"

                Save-GitHubRepoFile -Owner 'prowler-cloud' -Repo 'prowler' -Ref $Ref `
                    -Path $pyRepoPath -Destination $pyDest

                # Convert to PowerShell
                Write-Verbose "    Converting: $checkName"
                Convert-ProwlerCheck -CheckPath $tempCheckDir | Out-Null
                Write-Verbose "    Done"

                $success.Add($checkName)
            }
            catch {
                Write-Verbose "    Failed: $_"
                $failed.Add($checkName)
            }
        }

        Write-Verbose "Summary: Downloaded=$($success.Count), Skipped=$($skipped.Count), Failed=$($failed.Count)"

        [PSCustomObject]@{
            Success = @($success)
            Failed  = @($failed)
            Skipped = @($skipped)
        }
    }
    finally {
        # Clean up temp directory
        if (Test-Path $tempDir) {
            Write-Verbose "Cleaning up temp directory..."
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
