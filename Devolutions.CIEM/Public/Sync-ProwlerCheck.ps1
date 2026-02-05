function Sync-ProwlerCheck {
    <#
    .SYNOPSIS
        Syncs new Prowler checks from the upstream GitHub repository.

    .DESCRIPTION
        Downloads check files from the Prowler GitHub repository that are not yet
        present locally. No git clone or upstream remote is required.

        After downloading, new checks are automatically converted to PowerShell format.

        Use Get-ProwlerCheck to preview available checks first.

    .PARAMETER Provider
        Filter to a specific provider (azure, aws, gcp).
        If not specified, syncs all providers defined in CIEM config.

    .PARAMETER Service
        Filter to a specific service (e.g., entra, iam, storage).

    .PARAMETER Ref
        Branch, tag, or commit SHA to sync from. Defaults to 'master'.

    .EXAMPLE
        Sync-ProwlerCheck
        # Syncs all check files for supported providers

    .EXAMPLE
        Sync-ProwlerCheck -Provider azure -Service entra
        # Syncs only Entra-related checks

    .EXAMPLE
        Sync-ProwlerCheck -Ref 'v4.0.0'
        # Syncs checks from the v4.0.0 tag
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet('azure', 'aws', 'gcp')]
        [string]$Provider,

        [Parameter()]
        [string]$Service,

        [Parameter()]
        [string]$Ref = 'master'
    )

    $ErrorActionPreference = 'Stop'

    # Resolve local prowler providers path
    $prowlerProvidersPath = Join-Path $script:ModuleRoot $script:Config.prowler.path

    $providersToSync = if ($Provider) {
        @($Provider)
    }
    else {
        (Get-CIEMProvider).Name.ToLower()
    }

    Write-Verbose "Syncing Prowler checks from GitHub..."
    Write-Verbose "  Providers: $($providersToSync -join ', ')"
    if ($Service) { Write-Verbose "  Service: $Service" }
    Write-Verbose "  Ref: $Ref"
    Write-Verbose "  Local path: $prowlerProvidersPath"

    # Get available checks from GitHub
    $splatParams = @{ Ref = $Ref; ErrorAction = 'Stop' }
    if ($Provider) { $splatParams.Provider = $Provider }
    if ($Service) { $splatParams.Service = $Service }
    $availableChecks = @(Get-ProwlerCheck @splatParams)

    if ($availableChecks.Count -eq 0) {
        Write-Verbose "No checks found upstream."
        return [PSCustomObject]@{ Success = @(); Failed = @(); Skipped = @() }
    }

    Write-Verbose "Found $($availableChecks.Count) checks upstream."

    $success = [System.Collections.Generic.List[string]]::new()
    $failed = [System.Collections.Generic.List[string]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()

    foreach ($check in $availableChecks) {
        $localCheckDir = Join-Path $prowlerProvidersPath "$($check.Provider)/services/$($check.Service)/$($check.Name)"

        if (Test-Path $localCheckDir) {
            Write-Verbose "  Skipping $($check.Name) - already exists locally"
            $skipped.Add($check.Name)
            continue
        }

        Write-Verbose "  Downloading $($check.Name) ($($check.Files.Count) files)..."

        try {
            foreach ($file in $check.Files) {
                # Map GitHub path to local path
                # GitHub: prowler/providers/{provider}/services/{service}/{check}/{file}
                # Local:  {prowlerProvidersPath}/{provider}/services/{service}/{check}/{file}
                $relativePath = $file -replace '^prowler/providers/', ''
                $destination = Join-Path $prowlerProvidersPath $relativePath

                Save-GitHubRepoFile -Owner 'prowler-cloud' -Repo 'prowler' -Ref $Ref -Path $file -Destination $destination -ErrorAction Stop
            }

            Write-Verbose "    Downloaded"
            $success.Add($check.Name)
        }
        catch {
            Write-Verbose "    Failed: $_"
            $failed.Add($check.Name)
        }
    }

    # Convert newly downloaded checks to PowerShell
    if ($success.Count -gt 0) {
        Write-Verbose "Converting $($success.Count) new check(s) to PowerShell..."

        foreach ($checkName in $success) {
            $check = $availableChecks | Where-Object { $_.Name -eq $checkName }
            $localCheckDir = Join-Path $prowlerProvidersPath "$($check.Provider)/services/$($check.Service)/$($check.Name)"

            Write-Verbose "  Converting: $checkName"
            try {
                Convert-ProwlerCheck -CheckPath $localCheckDir | Out-Null
                Write-Verbose "    Done"
            }
            catch {
                Write-Verbose "    Conversion failed: $_"
            }
        }
    }

    Write-Verbose "Summary: Downloaded=$($success.Count), Skipped=$($skipped.Count), Failed=$($failed.Count)"

    [PSCustomObject]@{
        Success = @($success)
        Failed  = @($failed)
        Skipped = @($skipped)
    }
}
