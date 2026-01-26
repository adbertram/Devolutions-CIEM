function Get-ProwlerCheck {
    <#
    .SYNOPSIS
        Lists available Prowler checks from the upstream repository.

    .DESCRIPTION
        Queries the upstream Prowler repository for security checks that have been
        added or modified. Returns one object per check with Date, Provider, Service,
        Name, and associated Files.

    .PARAMETER Provider
        Filter to a specific provider (azure, aws, gcp).

    .PARAMETER Service
        Filter to a specific service (e.g., entra, iam, storage).

    .PARAMETER Since
        Only show checks since this date. Defaults to 30 days ago.

    .PARAMETER Limit
        Maximum number of commits to search. Defaults to 50.

    .EXAMPLE
        Get-ProwlerCheck

    .EXAMPLE
        Get-ProwlerCheck -Service entra

    .OUTPUTS
        PSCustomObject with properties: Date, Provider, Service, Name, Files
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
        [string]$Since = '30 days ago',

        [Parameter()]
        [int]$Limit = 50
    )

    $ErrorActionPreference = 'Stop'

    # Get supported providers from config
    $supportedProviders = Get-SupportedProvider

    # Verify upstream remote
    Test-GitRemote

    $providersToQuery = if ($Provider) { @($Provider) } else { $supportedProviders }

    Write-Verbose "Searching for check commits..."
    Write-Verbose "  Providers: $($providersToQuery -join ', ')"
    Write-Verbose "  Since: $Since"
    if ($Service) {
        Write-Verbose "  Service: $Service"
    }

    # Fetch from upstream
    $upstreamRemote = $script:Config.prowler.upstreamRemote
    Write-Verbose "Fetching from upstream..."
    git fetch $upstreamRemote --quiet 2>&1 | Out-Null

    # Build file patterns
    $filePatterns = @()
    foreach ($prov in $providersToQuery) {
        $servicePath = if ($Service) { $Service } else { '*' }
        $filePatterns += "prowler/providers/$prov/services/$servicePath/*/*.metadata.json"
        $filePatterns += "prowler/providers/$prov/services/$servicePath/*/*.py"
    }

    # Get commits
    $gitLogArgs = @(
        'log', "$upstreamRemote/master",
        "--since=`"$Since`"", "-n", $Limit,
        '--pretty=format:%H|%s|%an|%ad|%ar',
        '--date=short', '--diff-filter=AM', '--'
    ) + $filePatterns

    $logOutput = & git @gitLogArgs 2>&1

    if ($logOutput) {
        # Parse commits and extract check information
        $logOutput | Where-Object { $_ -and $_ -notmatch '^warning:' } | ForEach-Object {
            $parts = $_ -split '\|', 5
            if ($parts.Count -ge 5) {
                $hash = $parts[0]
                $date = $parts[3]

                # Get files for this commit
                $files = git show --name-only --pretty=format: $hash -- @filePatterns 2>&1 |
                    Where-Object { $_ -and $_ -match '\.metadata\.json$|\.py$' }

                # Extract unique checks from file paths
                $seenChecks = @{}
                foreach ($file in $files) {
                    if ($file -match 'providers/([^/]+)/services/([^/]+)/([^/]+)/') {
                        $fileProvider = $Matches[1]
                        $fileService = $Matches[2]
                        $checkId = $Matches[3]

                        # Create one object per unique check
                        if (-not $seenChecks.ContainsKey($checkId)) {
                            $seenChecks[$checkId] = $true
                            $checkFiles = @($files | Where-Object { $_ -match "/$checkId/" })
                            [PSCustomObject]@{
                                Date     = $date
                                Provider = $fileProvider
                                Service  = $fileService
                                Name     = $checkId
                                Files    = $checkFiles
                            }
                        }
                    }
                }
            }
        }
    }
    else {
        Write-Verbose "No check-related commits found."
    }
}
