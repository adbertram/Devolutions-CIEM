function Invoke-CIEMScan {
    <#
    .SYNOPSIS
        Executes CIEM security checks against cloud resources (internal).

    .DESCRIPTION
        Connects to the specified providers, initializes service data, and
        executes selected checks sequentially, emitting findings to the pipeline
        as each check completes.

        This is an internal function called by New-CIEMScanRun. It does not
        create or manage ScanRun lifecycle — the caller is responsible for that.

    .PARAMETER Provider
        One or more cloud providers to scan ('Azure', 'AWS'). Required.

    .PARAMETER CheckId
        Optional array of check IDs to run. If not specified, runs all checks.

    .PARAMETER Service
        Optional service filter. Only runs checks for specified service(s).

    .PARAMETER IncludePassed
        Whether to include passed checks in results. Default is false.

    .OUTPUTS
        [CIEMScanResult[]] Finding objects emitted to the pipeline as each check completes.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        [string[]]$Provider,

        [Parameter()]
        [string[]]$CheckId,

        [Parameter()]
        [string[]]$Service,

        [Parameter()]
        [switch]$IncludePassed
    )

    $ErrorActionPreference = 'Stop'

    Write-CIEMLog -Message "Invoke-CIEMScan called: Provider=[$($Provider -join ',')], CheckId=[$($CheckId -join ',')], Service=[$($Service -join ',')]" -Severity INFO -Component 'Scan'

    $providerCount = $Provider.Count
    $progressActivity = "CIEM Scan ($($Provider -join ', '))"

    # Connect to all requested providers at once (Connect-CIEM already supports arrays)
    Write-Progress -Activity $progressActivity -Status "Connecting to $($Provider -join ', ')..." -PercentComplete 0
    $connectResult = Connect-CIEM -Provider $Provider -Force

    # Loop over each provider sequentially
    $providerIdx = 0
    foreach ($providerName in $Provider) {
        $providerIdx++
        $providerResult = $connectResult.Providers | Where-Object { $_.Provider -eq $providerName }

        # Skip this provider if connection failed; mark its checks as SKIPPED
        if (-not $providerResult -or $providerResult.Status -ne 'Connected') {
            $failMsg = if ($providerResult) { $providerResult.Message } else { 'No connection result returned' }
            Write-Warning "Skipping $providerName (connection failed): $failMsg"

            # Emit SKIPPED for each check belonging to this provider
            $skippedChecks = @(Get-CIEMCheck -Provider $providerName)
            if ($CheckId) { $skippedChecks = @($skippedChecks | Where-Object { $CheckId -contains $_.Id }) }
            if ($Service)  { $skippedChecks = @($skippedChecks | Where-Object { $Service  -contains $_.Service.ToString() }) }

            foreach ($skippedCheck in $skippedChecks) {
                [CIEMScanResult]::Create($skippedCheck, 'SKIPPED', "Provider $providerName failed to connect: $failMsg", 'N/A', 'N/A')
            }
            continue
        }

        $authContext    = $script:AuthContext[$providerName]
        $subscriptionIds = @(if ($authContext.PSObject.Properties['SubscriptionIds']) { $authContext.SubscriptionIds } else { @() })

        Write-Verbose "[$providerName] Authenticated as: $($authContext.AccountId) ($($authContext.AccountType))"

        # --- Check discovery first: determine what will run before fetching any data ---
        # Filesystem-first: scripts on disk are the authority for which checks exist.
        # DB provides metadata (title, severity, description, remediation, permissions).
        $providerModuleRoot = switch ($providerName) {
            'Azure' { Join-Path $script:ModuleRoot 'modules/Azure' }
            'AWS'   { Join-Path $script:ModuleRoot 'modules/AWS' }
            default { $null }
        }
        $checkScriptsPath = if ($providerModuleRoot) { Join-Path $providerModuleRoot 'Checks' } else { $null }
        $checkScripts     = Get-ChildItem -Path "$checkScriptsPath/*.ps1" -ErrorAction SilentlyContinue

        if (-not $checkScripts -or $checkScripts.Count -eq 0) {
            Write-Warning "[$providerName] No check scripts found in $checkScriptsPath — skipping provider."
            continue
        }

        # Dot-source all check scripts (loads function definitions — fast, no API calls)
        foreach ($scriptFile in $checkScripts) { . $scriptFile.FullName }

        # Load DB metadata and build lookup by script filename
        $dbChecks = @(Get-CIEMCheck -Provider $providerName)
        $dbChecksByScript = @{}
        foreach ($dbCheck in $dbChecks) {
            if ($dbCheck.CheckScript) {
                $dbChecksByScript[$dbCheck.CheckScript] = $dbCheck
            }
        }

        # Build execution list from filesystem scripts, enriched with DB metadata
        $checks = [System.Collections.Generic.List[object]]::new()
        foreach ($scriptFile in $checkScripts) {
            $fileName     = $scriptFile.Name                          # e.g. Test-EntraSecurityDefaults.ps1
            $functionName = $fileName -replace '\.ps1$', ''           # e.g. Test-EntraSecurityDefaults

            # Look up DB metadata by filename
            $dbCheck = $dbChecksByScript[$fileName]

            if ($dbCheck) {
                # DB entry exists — use it (includes id, service, severity, title, etc.)
                $check = $dbCheck
            } else {
                # No DB entry — derive minimal metadata from filename conventions
                $derivedId = ($functionName -creplace '([a-z])([A-Z])', '$1_$2' -creplace '([A-Z]+)([A-Z][a-z])', '$1_$2').ToLower() -replace '-', '_'
                $derivedTitle = ($functionName -replace '^Test-', '') -creplace '([a-z])([A-Z])', '$1 $2' -creplace '([A-Z]+)([A-Z][a-z])', '$1 $2'
                $derivedService = if ($functionName -match '^Test-([A-Z][a-z]+)') { $Matches[1] } else { 'Unknown' }

                $check = [CIEMCheck]@{
                    Id          = $derivedId
                    Provider    = $providerName
                    Service     = $derivedService
                    Title       = $derivedTitle
                    Severity    = [CIEMCheckSeverity]::medium
                    CheckScript = $fileName
                    Disabled    = $false
                }
                Write-Verbose "[$providerName] No DB metadata for $fileName — using derived defaults (service=$derivedService)"
                # Persist derived check to DB so scan_results FK constraint is satisfied
                Save-CIEMCheck -InputObject $check
            }

            # Apply filters
            if ($CheckId) {
                if ($CheckId -notcontains $check.Id) { continue }
            }
            if ($Service) {
                if ($Service -notcontains $check.Service.ToString()) { continue }
            }
            if ($check.Disabled) {
                Write-Verbose "[$providerName] Skipping disabled check: $($check.Id)"
                continue
            }

            # Verify the function actually loaded
            if (-not (Get-Command -Name $functionName -ErrorAction SilentlyContinue)) {
                Write-Warning "[$providerName] Script $fileName dot-sourced but function $functionName not found — skipping"
                continue
            }

            $checks.Add($check)
        }

        if ($checks.Count -eq 0) {
            Write-Verbose "[$providerName] No checks to execute after filtering; skipping provider."
            continue
        }

        Write-Verbose "[$providerName] Checks to execute: $($checks.Count) (from $($checkScripts.Count) scripts, $($dbChecks.Count) DB entries)"

        # Derive required services from the checks that will actually run (+ their DependsOn)
        $servicesToInit = @(
            @($checks | ForEach-Object { $_.Service.ToString() }) +
            @($checks | Where-Object { $_.DependsOn } | ForEach-Object { $_.DependsOn }) |
            Select-Object -Unique
        )
        Write-Verbose "[$providerName] Services to initialize (derived from checks): $($servicesToInit -join ', ')"

        # Initialize only the services needed by the filtered checks
        $providerObj        = Get-CIEMProvider -Name $providerName
        $serviceCacheLookup = @{}
        $statusText         = "Scanning $providerName... ($providerIdx of $providerCount providers)"
        Write-Progress -Activity $progressActivity -Status $statusText -PercentComplete ([math]::Floor((($providerIdx - 1) / $providerCount) * 80 + 5))

        switch ($providerName) {
            'Azure' {
                $sw = [Diagnostics.Stopwatch]::new()

                # Tenant-scoped services (no subscription required)
                if ('Entra' -in $servicesToInit) {
                    $sw.Restart()
                    try {
                        $svcData = Get-CIEMAzureEntraData
                        $serviceCacheLookup['Entra'] = [CIEMServiceCache]@{
                            ServiceName = 'Entra'; Success = $true; Duration = $sw.Elapsed
                            CacheData = $svcData; Errors = @(); Warnings = @(); Output = @()
                        }
                        Write-Verbose "[$providerName] Initialized Entra in $([math]::Round($sw.Elapsed.TotalSeconds, 2))s"
                    } catch {
                        $serviceCacheLookup['Entra'] = [CIEMServiceCache]@{
                            ServiceName = 'Entra'; Success = $false; Duration = $sw.Elapsed
                            CacheData = @{}; Errors = @($_.Exception.Message); Warnings = @(); Output = @()
                        }
                        Write-Warning "[$providerName] Failed to initialize Entra: $($_.Exception.Message)"
                    }
                }

                # Subscription-scoped services
                foreach ($svcName in @('IAM', 'Defender', 'Monitor', 'Network', 'Policy', 'Vm')) {
                    if ($svcName -notin $servicesToInit) { continue }
                    $sw.Restart()
                    $getFn = "Get-CIEMAzure${svcName}Data"
                    try {
                        $svcData = & $getFn
                        $serviceCacheLookup[$svcName] = [CIEMServiceCache]@{
                            ServiceName = $svcName; Success = $true; Duration = $sw.Elapsed
                            CacheData = $svcData; Errors = @(); Warnings = @(); Output = @()
                        }
                        Write-Verbose "[$providerName] Initialized $svcName in $([math]::Round($sw.Elapsed.TotalSeconds, 2))s"
                    } catch {
                        $serviceCacheLookup[$svcName] = [CIEMServiceCache]@{
                            ServiceName = $svcName; Success = $false; Duration = $sw.Elapsed
                            CacheData = @{}; Errors = @($_.Exception.Message); Warnings = @(); Output = @()
                        }
                        Write-Warning "[$providerName] Failed to initialize ${svcName}: $($_.Exception.Message)"
                    }
                }
            }
            'AWS' {
                $sw = [Diagnostics.Stopwatch]::new()
                foreach ($svcName in $servicesToInit) {
                    $sw.Restart()
                    $getFn = "Get-CIEMAWS${svcName}Data"
                    if (Get-Command $getFn -ErrorAction SilentlyContinue) {
                        try {
                            $svcData = & $getFn
                            $serviceCacheLookup[$svcName] = [CIEMServiceCache]@{
                                ServiceName = $svcName; Success = $true; Duration = $sw.Elapsed
                                CacheData = $svcData; Errors = @(); Warnings = @(); Output = @()
                            }
                            Write-Verbose "[$providerName] Initialized $svcName in $([math]::Round($sw.Elapsed.TotalSeconds, 2))s"
                        } catch {
                            $serviceCacheLookup[$svcName] = [CIEMServiceCache]@{
                                ServiceName = $svcName; Success = $false; Duration = $sw.Elapsed
                                CacheData = @{}; Errors = @($_.Exception.Message); Warnings = @(); Output = @()
                            }
                            Write-Warning "[$providerName] Failed to initialize ${svcName}: $($_.Exception.Message)"
                        }
                    } else {
                        Write-Verbose "[$providerName] No service function for $svcName — checks will run as stubs"
                    }
                }
            }
        }

        # Persist collected service data to SQLite normalized tables
        $saveParams = @{ ProviderId = $providerName.ToLower() }
        $serviceMap = @{
            EntraData    = 'Entra'
            IAMData      = 'IAM'
            DefenderData = 'Defender'
            MonitorData  = 'Monitor'
            NetworkData  = 'Network'
            PolicyData   = 'Policy'
            VmData       = 'Vm'
        }
        foreach ($param in $serviceMap.Keys) {
            $svc = $serviceMap[$param]
            if ($serviceCacheLookup.ContainsKey($svc) -and $serviceCacheLookup[$svc].Success) {
                $saveParams[$param] = $serviceCacheLookup[$svc].CacheData
            }
        }
        if ($authContext.PSObject.Properties['TenantId']) { $saveParams.TenantId = $authContext.TenantId }

        if ($saveParams.Count -gt 2) {  # more than ProviderId + TenantId
            try {
                Save-CIEMCollectedData @saveParams
                Write-Verbose "[$providerName] Collected data persisted to SQLite"
            }
            catch {
                Write-Warning "[$providerName] Failed to persist collected data: $($_.Exception.Message)"
            }
        }

        # Build identity-to-resource relationship graph (only if Entra/IAM checks need it)
        if (Get-Command -Name 'New-CIEMGraph' -ErrorAction SilentlyContinue) {
            try {
                if ($serviceCacheLookup.ContainsKey('Entra') -and $serviceCacheLookup['Entra'].Success) {
                    $graphEntraData = $serviceCacheLookup['Entra'].CacheData
                    $graphIAMData = if ($serviceCacheLookup.ContainsKey('IAM') -and $serviceCacheLookup['IAM'].Success) { $serviceCacheLookup['IAM'].CacheData } else { @{} }

                    Write-Verbose "[$providerName] Building identity relationship graph..."
                    $sw = [Diagnostics.Stopwatch]::StartNew()
                    $ciemGraph = New-CIEMGraph -EntraData $graphEntraData -IAMData $graphIAMData -TenantId $authContext.TenantId
                    $sw.Stop()
                    Write-Verbose "[$providerName] Graph built in $([math]::Round($sw.Elapsed.TotalSeconds, 2))s: $($ciemGraph.Nodes.Count) nodes, $($ciemGraph.Edges.Count) edges"

                    # Inject as synthetic service cache entry
                    $graphCache = [CIEMServiceCache]::new()
                    $graphCache.ServiceName = 'Graph'
                    $graphCache.Success = $true
                    $graphCache.Duration = $sw.Elapsed
                    $graphCache.Errors = @()
                    $graphCache.Warnings = @()
                    $graphCache.Output = @()
                    $graphCache.CacheData = @{ Graph = $ciemGraph }
                    $serviceCacheLookup['Graph'] = $graphCache
                }
                else {
                    Write-Verbose "[$providerName] Skipping graph build — Entra service cache unavailable"
                }
            }
            catch {
                Write-Warning "[$providerName] Graph build failed (non-fatal): $($_.Exception.Message)"
            }
        }

        # Execute checks and emit findings to pipeline
        $checkIndex  = 0
        $totalChecks = $checks.Count

        foreach ($check in $checks) {
            $checkIndex++
            $providerBasePct = [math]::Floor((($providerIdx - 1) / $providerCount) * 80 + 5)
            $checkPct        = $providerBasePct + [math]::Floor(($checkIndex / $totalChecks) * (80 / $providerCount))
            Write-Progress -Activity $progressActivity -Status "$statusText - check $checkIndex of $totalChecks" -CurrentOperation $check.Title -PercentComplete $checkPct

            $functionName = $check.CheckScript -replace '\.ps1$', ''
            Write-Verbose "[$providerName] Running check: $($check.Id)"

            # Resolve service caches for this check
            $checkService = $check.Service.ToString()
            $neededServices = @($checkService)
            if ($check.DependsOn) { $neededServices += $check.DependsOn }
            $checkCaches = @($neededServices | ForEach-Object {
                if ($serviceCacheLookup.ContainsKey($_)) { $serviceCacheLookup[$_] }
            } | Where-Object { $_ })

            Invoke-CIEMCheck -Check $check -ServiceCache $checkCaches -FunctionName $functionName -ProviderName $providerName
        }

        Write-Verbose "[$providerName] Provider scan complete."
    }

    Write-Progress -Activity $progressActivity -Completed
}
