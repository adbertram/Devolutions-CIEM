function Get-ProwlerChecks {
    <#
    .SYNOPSIS
        Lists available Prowler check commits from the upstream repository.

    .DESCRIPTION
        Queries the upstream Prowler repository for commits that add or modify
        security checks. Only shows commits for providers defined in config.json.

    .PARAMETER Provider
        Filter to a specific provider (azure, aws, gcp).

    .PARAMETER Service
        Filter to a specific service (e.g., entra, iam, storage).

    .PARAMETER Since
        Only show commits since this date. Defaults to 30 days ago.

    .PARAMETER Limit
        Maximum number of commits to display. Defaults to 50.

    .EXAMPLE
        Get-ProwlerChecks

    .EXAMPLE
        Get-ProwlerChecks -Service entra
    #>
    [CmdletBinding()]
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
    $knownProviders = @('azure', 'aws', 'gcp')
    $supportedProviders = @()
    foreach ($key in ($script:Config | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)) {
        if ($knownProviders -contains $key.ToLower()) {
            $supportedProviders += $key.ToLower()
        }
    }
    if ($supportedProviders.Count -eq 0) {
        throw "No supported providers found in config.json"
    }

    # Verify upstream remote
    $upstreamRemote = $script:Config.prowler.upstreamRemote
    $remotes = (git remote -v 2>&1) -join "`n"
    if ($remotes -notmatch "$upstreamRemote.*prowler") {
        throw "Upstream remote '$upstreamRemote' not configured. Run: git remote add $upstreamRemote https://github.com/prowler-cloud/prowler.git"
    }

    $providersToQuery = if ($Provider) { @($Provider) } else { $supportedProviders }

    Write-Host "Searching for check commits..." -ForegroundColor Cyan
    Write-Host "  Providers: $($providersToQuery -join ', ')" -ForegroundColor DarkGray
    Write-Host "  Since: $Since" -ForegroundColor DarkGray
    if ($Service) {
        Write-Host "  Service: $Service" -ForegroundColor DarkGray
    }

    # Fetch from upstream
    Write-Host "Fetching from upstream..." -ForegroundColor Cyan
    git fetch $upstreamRemote --quiet 2>&1 | Out-Null

    # Build file patterns using config path
    $prowlerPath = Join-Path $script:ModuleRoot $script:Config.prowler.path
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

    if (-not $logOutput) {
        Write-Host "`nNo check-related commits found." -ForegroundColor Yellow
        return @()
    }

    $commits = $logOutput | Where-Object { $_ -and $_ -notmatch '^warning:' } | ForEach-Object {
        $parts = $_ -split '\|', 5
        if ($parts.Count -ge 5) {
            [PSCustomObject]@{
                Hash         = $parts[0]
                ShortHash    = $parts[0].Substring(0, 8)
                Subject      = $parts[1]
                Author       = $parts[2]
                Date         = $parts[3]
                RelativeDate = $parts[4]
                Files        = @()
                NewChecks    = @()
                Provider     = ''
                Services     = @()
            }
        }
    }

    # Get files for each commit
    foreach ($commit in $commits) {
        $files = git show --name-only --pretty=format: $commit.Hash -- @filePatterns 2>&1 |
            Where-Object { $_ -and $_ -match '\.metadata\.json$|\.py$' }
        $commit.Files = @($files)

        $checkIds = @(); $providers = @(); $services = @()
        foreach ($file in $files) {
            if ($file -match 'providers/([^/]+)/services/([^/]+)/([^/]+)/') {
                if ($providers -notcontains $Matches[1]) { $providers += $Matches[1] }
                if ($services -notcontains $Matches[2]) { $services += $Matches[2] }
                if ($checkIds -notcontains $Matches[3]) { $checkIds += $Matches[3] }
            }
        }
        $commit.Provider = $providers -join ', '
        $commit.Services = $services
        $commit.NewChecks = $checkIds
    }

    $commits = $commits | Where-Object { $_.Files.Count -gt 0 }

    if ($commits.Count -eq 0) {
        Write-Host "`nNo check-related commits found." -ForegroundColor Yellow
        return @()
    }

    Write-Host "`nFound $($commits.Count) check-related commits:`n" -ForegroundColor Green

    $commits | ForEach-Object {
        [PSCustomObject]@{
            Hash     = $_.ShortHash
            Date     = $_.Date
            Provider = $_.Provider
            Checks   = ($_.NewChecks | Select-Object -First 3) -join ', '
            Subject  = if ($_.Subject.Length -gt 50) { $_.Subject.Substring(0, 47) + '...' } else { $_.Subject }
        }
    } | Format-Table -AutoSize

    Write-Host "To sync, run: Sync-ProwlerChecks" -ForegroundColor Cyan

    return $commits
}
