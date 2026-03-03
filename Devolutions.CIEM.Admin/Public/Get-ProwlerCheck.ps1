function Get-ProwlerCheck {
    <#
    .SYNOPSIS
        Lists available Prowler checks from the upstream GitHub repository.

    .DESCRIPTION
        Queries the Prowler GitHub repository via the Trees API to discover security checks.
        Returns one object per check with Provider, Service, Name, and associated Files.

        No local git clone or upstream remote is required.

    .PARAMETER Provider
        Filter to a specific provider (azure, aws, gcp).

    .PARAMETER Service
        Filter to a specific service (e.g., entra, iam, storage).

    .PARAMETER Ref
        Branch, tag, or commit SHA to query. Defaults to 'master'.

    .EXAMPLE
        Get-ProwlerCheck

    .EXAMPLE
        Get-ProwlerCheck -Provider azure -Service entra

    .OUTPUTS
        PSCustomObject with properties: Provider, Service, Name, Files
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateSet('azure', 'aws', 'gcp')]
        [string]$Provider,

        [Parameter()]
        [string]$Service,

        [Parameter()]
        [string]$Ref = 'master'
    )

    $shouldThrow = $ErrorActionPreference -eq 'Stop'
    $ErrorActionPreference = 'Stop'

    # Derive supported providers from checks registered in the SQLite checks table
    $supportedProviders = @(Get-CIEMCheck | ForEach-Object { $_.Provider.ToLower() } | Select-Object -Unique)
    $providersToQuery = if ($Provider) { @($Provider) } else { $supportedProviders }

    Write-Verbose "Searching for Prowler checks via GitHub API..."
    Write-Verbose "  Providers: $($providersToQuery -join ', ')"
    if ($Service) { Write-Verbose "  Service: $Service" }
    Write-Verbose "  Ref: $Ref"

    foreach ($prov in $providersToQuery) {
        $path = "prowler/providers/$prov/services"
        if ($Service) {
            $path = "prowler/providers/$prov/services/$Service"
        }

        try {
            $tree = Get-GitHubRepoTree -Owner 'prowler-cloud' -Repo 'prowler' -Ref $Ref -Path $path -ErrorAction Stop
        }
        catch {
            $msg = "Failed to fetch check tree for provider '$prov': $_"
            if ($shouldThrow) { throw $msg }
            Write-Warning $msg
            continue
        }

        # Checks are identified by having a .metadata.json file
        $metadataFiles = $tree | Where-Object { $_.Type -eq 'blob' -and $_.Path -match '\.metadata\.json$' }

        foreach ($metaFile in $metadataFiles) {
            if ($metaFile.Path -match 'providers/([^/]+)/services/([^/]+)/([^/]+)/') {
                $checkProvider = $Matches[1]
                $checkService = $Matches[2]
                $checkId = $Matches[3]

                $checkPrefix = "prowler/providers/$checkProvider/services/$checkService/$checkId/"
                $checkFiles = @($tree | Where-Object { $_.Type -eq 'blob' -and $_.Path -like "$checkPrefix*" })

                [PSCustomObject]@{
                    Provider = $checkProvider
                    Service  = $checkService
                    Name     = $checkId
                    Files    = @($checkFiles.Path)
                }
            }
        }
    }
}
