function Sync-ProwlerChecks {
    <#
    .SYNOPSIS
        Syncs new Prowler checks from the upstream repository.

    .DESCRIPTION
        Extracts check files from the upstream Prowler repository that add or modify
        security checks. Only syncs providers defined in config.json.

        By default, syncs all available check commits. Use -CherryPick to sync specific commits.

        After syncing, new checks are automatically converted to PowerShell format.

        Use Get-ProwlerChecks to preview available commits first.

    .PARAMETER Provider
        Filter to a specific provider (azure, aws, gcp).
        If not specified, syncs all providers defined in config.json.

    .PARAMETER Service
        Filter to a specific service (e.g., entra, iam, storage).

    .PARAMETER Since
        Only consider commits since this date. Defaults to 30 days ago.
        Format: YYYY-MM-DD or relative like "30 days ago"

    .PARAMETER CherryPick
        Comma-separated list of commit hashes to sync.
        If not specified, syncs all available commits.

    .EXAMPLE
        Sync-ProwlerChecks
        # Syncs all check commits for supported providers

    .EXAMPLE
        Sync-ProwlerChecks -CherryPick "abc1234,def5678"
        # Syncs only specific commits

    .EXAMPLE
        Sync-ProwlerChecks -Service entra
        # Syncs only Entra-related check commits

    .NOTES
        Requires git and the upstream remote to be configured:
        git remote add upstream https://github.com/prowler-cloud/prowler.git
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
        [string]$CherryPick
    )

    $ErrorActionPreference = 'Stop'

    #region Helper Functions

    function Get-SupportedProviders {
        $knownProviders = @('azure', 'aws', 'gcp')

        $supported = @()
        foreach ($key in ($script:Config | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)) {
            if ($knownProviders -contains $key.ToLower()) {
                $supported += $key.ToLower()
            }
        }

        if ($supported.Count -eq 0) {
            throw "No supported providers found in config.json. Expected top-level keys: azure, aws, or gcp"
        }

        return $supported
    }

    function Test-GitRemote {
        $upstreamRemote = $script:Config.prowler.upstreamRemote
        $remotes = (git remote -v 2>&1) -join "`n"
        if ($remotes -notmatch "$upstreamRemote.*prowler") {
            throw @"
Upstream remote '$upstreamRemote' not configured. Please run:
    git remote add $upstreamRemote https://github.com/prowler-cloud/prowler.git
"@
        }
    }

    function Get-CheckPathPattern {
        param(
            [string[]]$Providers,
            [string]$Service
        )

        $patterns = @()
        foreach ($prov in $Providers) {
            $servicePath = if ($Service) { $Service } else { '*' }
            $patterns += "prowler/providers/$prov/services/$servicePath/*/"
        }

        return $patterns
    }

    function Get-UpstreamCheckCommits {
        param(
            [string[]]$PathPatterns,
            [string]$Since,
            [int]$Limit = 100
        )

        $upstreamRemote = $script:Config.prowler.upstreamRemote

        Write-Host "Fetching from upstream..." -ForegroundColor Cyan
        git fetch $upstreamRemote --quiet 2>&1 | Out-Null

        $filePatterns = @()
        foreach ($pattern in $PathPatterns) {
            $filePatterns += "${pattern}*.metadata.json"
            $filePatterns += "${pattern}*.py"
        }

        $gitLogArgs = @(
            'log',
            "$upstreamRemote/master",
            "--since=`"$Since`"",
            "-n", $Limit,
            '--pretty=format:%H|%s|%an|%ad|%ar',
            '--date=short',
            '--diff-filter=AM',
            '--'
        ) + $filePatterns

        $logOutput = & git @gitLogArgs 2>&1

        if (-not $logOutput) {
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

        foreach ($commit in $commits) {
            $files = git show --name-only --pretty=format: $commit.Hash -- @filePatterns 2>&1 |
                Where-Object { $_ -and $_ -match '\.metadata\.json$|\.py$' }

            $commit.Files = @($files)

            $checkIds = @()
            $providers = @()
            $services = @()

            foreach ($file in $files) {
                if ($file -match 'providers/([^/]+)/services/([^/]+)/([^/]+)/') {
                    $prov = $Matches[1]
                    $svc = $Matches[2]
                    $checkId = $Matches[3]

                    if ($providers -notcontains $prov) { $providers += $prov }
                    if ($services -notcontains $svc) { $services += $svc }
                    if ($checkIds -notcontains $checkId) { $checkIds += $checkId }
                }
            }

            $commit.Provider = $providers -join ', '
            $commit.Services = $services
            $commit.NewChecks = $checkIds
        }

        return @($commits | Where-Object { @($_.Files).Count -gt 0 })
    }

    function Show-CommitDetails {
        param(
            [array]$Commits,
            [string[]]$Providers
        )

        if ($Commits.Count -eq 0) {
            Write-Host "`nNo check-related commits found." -ForegroundColor Yellow
            Write-Host "Providers searched: $($Providers -join ', ')" -ForegroundColor DarkGray
            return
        }

        Write-Host "`nFound $($Commits.Count) check-related commits:`n" -ForegroundColor Green

        $tableData = $Commits | ForEach-Object {
            [PSCustomObject]@{
                Hash     = $_.ShortHash
                Date     = $_.Date
                Provider = $_.Provider
                Checks   = ($_.NewChecks | Select-Object -First 3) -join ', '
                Subject  = if ($_.Subject.Length -gt 50) { $_.Subject.Substring(0, 47) + '...' } else { $_.Subject }
            }
        }

        $tableData | Format-Table -AutoSize
    }

    function Invoke-CheckSync {
        param(
            [array]$Commits,
            [string[]]$PathPatterns
        )

        $results = @{
            Success = @()
            Failed  = @()
            Skipped = @()
        }

        # Build regex pattern for check files only
        # Upstream paths are: prowler/providers/{provider}/services/{service}/{check}/*
        # Local paths are:    prowler/prowler/providers/{provider}/services/{service}/{check}/*
        $checkPathRegex = '^prowler/providers/[^/]+/services/[^/]+/[^/]+/'

        foreach ($commit in $Commits) {
            $hash = if ($commit -is [string]) { $commit } else { $commit.Hash }
            $shortHash = $hash.Substring(0, [Math]::Min(8, $hash.Length))

            # Get all files changed in this commit
            $allFiles = @(git show --name-only --pretty=format: $hash 2>&1 | Where-Object { $_ })

            # Filter to ONLY check files (nothing else from the commit)
            $checkFiles = @($allFiles | Where-Object { $_ -match $checkPathRegex })

            if ($checkFiles.Count -eq 0) {
                Write-Host "  Skipping $shortHash - no check files" -ForegroundColor Yellow
                $results.Skipped += $hash
                continue
            }

            # Check which files need syncing
            # Map upstream paths (prowler/providers/...) to local paths (prowler/prowler/providers/...)
            $newFiles = @()
            foreach ($upstreamFile in $checkFiles) {
                $localFile = "prowler/$upstreamFile"
                if (-not (Test-Path $localFile)) {
                    $newFiles += @{ Upstream = $upstreamFile; Local = $localFile }
                }
                # If file exists locally, skip it (delete local file to force re-sync)
            }

            if ($newFiles.Count -eq 0) {
                Write-Host "  Skipping $shortHash - already synced" -ForegroundColor Yellow
                $results.Skipped += $hash
                continue
            }

            Write-Host "  Syncing $shortHash ($($newFiles.Count) file(s))..." -ForegroundColor Cyan

            try {
                # Extract check files from the commit to local paths
                foreach ($filePair in $newFiles) {
                    $localDir = Split-Path $filePair.Local -Parent
                    if (-not (Test-Path $localDir)) {
                        New-Item -ItemType Directory -Path $localDir -Force | Out-Null
                    }
                    # Get file content from upstream commit and write to local path
                    $content = git show "${hash}:$($filePair.Upstream)" 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to get content for $($filePair.Upstream)"
                    }
                    Set-Content -Path $filePair.Local -Value $content -NoNewline
                }

                # Stage and commit
                $localPaths = $newFiles | ForEach-Object { $_.Local }
                git add $localPaths 2>&1 | Out-Null
                git commit -m "Sync Prowler check: $shortHash" --no-verify 2>&1 | Out-Null

                Write-Host "    Success" -ForegroundColor Green
                $results.Success += $hash
            }
            catch {
                Write-Host "    Failed: $_" -ForegroundColor Red
                # Reset any staged changes
                git reset HEAD 2>&1 | Out-Null
                git checkout HEAD -- . 2>&1 | Out-Null
                $results.Failed += $hash
            }
        }

        return $results
    }

    function Get-NewCheckPaths {
        param([array]$Commits)

        $checkPaths = @()

        foreach ($commit in $Commits) {
            foreach ($file in $commit.Files) {
                if ($file -match '(prowler/providers/[^/]+/services/[^/]+/[^/]+)/' ) {
                    $checkPath = $Matches[1]
                    if ($checkPaths -notcontains $checkPath -and (Test-Path $checkPath)) {
                        $checkPaths += $checkPath
                    }
                }
            }
        }

        return $checkPaths
    }

    function Invoke-CheckConversion {
        param(
            [array]$Commits,
            [string[]]$SuccessHashes
        )

        $relevantCommits = @($Commits | Where-Object { $SuccessHashes -contains $_.Hash })
        $checkPaths = @(Get-NewCheckPaths -Commits $relevantCommits)

        if ($checkPaths.Count -eq 0) {
            Write-Host "`nNo new checks to convert." -ForegroundColor DarkGray
            return
        }

        Write-Host "`nConverting $($checkPaths.Count) check(s) to PowerShell..." -ForegroundColor Cyan

        foreach ($checkPath in $checkPaths) {
            $checkId = Split-Path $checkPath -Leaf
            Write-Host "  Converting: $checkId" -ForegroundColor DarkGray
            try {
                Convert-ProwlerCheck -CheckPath $checkPath | Out-Null
                Write-Host "    Done" -ForegroundColor Green
            }
            catch {
                Write-Host "    Failed: $_" -ForegroundColor Red
            }
        }
    }

    #endregion Helper Functions

    #region Main Logic

    Test-GitRemote

    $providersToSync = if ($Provider) {
        @($Provider)
    }
    else {
        Get-SupportedProviders
    }

    Write-Host "Syncing Prowler checks..." -ForegroundColor Cyan
    Write-Host "  Providers: $($providersToSync -join ', ')" -ForegroundColor DarkGray
    Write-Host "  Since: $Since" -ForegroundColor DarkGray
    if ($Service) {
        Write-Host "  Service: $Service" -ForegroundColor DarkGray
    }

    $pathPatterns = Get-CheckPathPattern -Providers $providersToSync -Service $Service
    $commits = @(Get-UpstreamCheckCommits -PathPatterns $pathPatterns -Since $Since)

    if ($commits.Count -eq 0) {
        Write-Host "`nNo commits to sync." -ForegroundColor Yellow
        return @{ Success = @(); Failed = @(); Skipped = @() }
    }

    # Determine which commits to sync
    if ($CherryPick) {
        $hashes = $CherryPick -split ',' | ForEach-Object { $_.Trim() }
        $commitsToSync = @(foreach ($hash in $hashes) {
            $found = $commits | Where-Object { $_.Hash -like "$hash*" -or $_.ShortHash -eq $hash }
            if ($found) {
                $found
            }
            else {
                [PSCustomObject]@{
                    Hash      = $hash
                    ShortHash = $hash.Substring(0, [Math]::Min(8, $hash.Length))
                    Files     = @()
                }
            }
        })
    }
    else {
        # Sync all by default
        $commitsToSync = @($commits)
    }

    Show-CommitDetails -Commits $commitsToSync -Providers $providersToSync

    Write-Host "`nSyncing $($commitsToSync.Count) commits..." -ForegroundColor Cyan
    $results = Invoke-CheckSync -Commits $commitsToSync

    if ($results.Success.Count -gt 0) {
        Invoke-CheckConversion -Commits $commits -SuccessHashes $results.Success
    }

    # Summary
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Success: $($results.Success.Count)" -ForegroundColor Green
    Write-Host "  Skipped: $($results.Skipped.Count)" -ForegroundColor Yellow
    Write-Host "  Failed:  $($results.Failed.Count)" -ForegroundColor Red

    return $results

    #endregion Main Logic
}
