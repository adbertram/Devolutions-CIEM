function Invoke-CIEMScan {
    <#
    .SYNOPSIS
        Executes CIEM security checks against cloud resources (internal).

    .DESCRIPTION
        Connects to the requested providers, validates check metadata, loads only the
        discovery data required by the selected checks, and executes checks in
        parallel while preserving Invoke-CIEMCheck behavior.

        This is an internal function called by New-CIEMScanRun. It does not create
        or manage ScanRun lifecycle.

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

    function ConvertToCIEMCheckObject {
        param(
            [Parameter(Mandatory)]
            [object]$CheckData
        )

        $ErrorActionPreference = 'Stop'

        $check = [CIEMCheck]::new()
        $check.Id = $CheckData.Id
        $check.Provider = $CheckData.Provider
        $check.Service = $CheckData.Service
        $check.Title = $CheckData.Title
        $check.Description = $CheckData.Description
        $check.Risk = $CheckData.Risk
        $check.Severity = [CIEMCheckSeverity]$CheckData.Severity
        $check.RelatedUrl = $CheckData.RelatedUrl
        $check.CheckScript = $CheckData.CheckScript
        $check.DependsOn = @($CheckData.DependsOn)
        $check.DataNeeds = @($CheckData.DataNeeds)
        $check.Disabled = [bool]$CheckData.Disabled

        $remediation = [CIEMCheckRemediation]::new()
        if ($CheckData.Remediation) {
            $remediation.Text = $CheckData.Remediation.Text
            $remediation.Url = $CheckData.Remediation.Url
        }
        $check.Remediation = $remediation

        $permissions = [CIEMCheckPermissions]::new()
        if ($CheckData.Permissions) {
            $permissions.Graph = @($CheckData.Permissions.Graph)
            $permissions.ARM = @($CheckData.Permissions.ARM)
            $permissions.KeyVaultDataPlane = @($CheckData.Permissions.KeyVaultDataPlane)
            $permissions.IAM = @($CheckData.Permissions.IAM)
        }
        $check.Permissions = $permissions

        $check
    }

    function EnsureServiceBucket {
        param(
            [Parameter(Mandatory)]
            [hashtable]$ServiceData,
            [Parameter(Mandatory)]
            [hashtable]$ServiceErrors,
            [Parameter(Mandatory)]
            [hashtable]$ServiceStarted,
            [Parameter(Mandatory)]
            [string]$ServiceName
        )

        $ErrorActionPreference = 'Stop'

        if (-not $ServiceData.ContainsKey($ServiceName)) {
            $ServiceData[$ServiceName] = @{}
            $ServiceErrors[$ServiceName] = @()
            $ServiceStarted[$ServiceName] = [Diagnostics.Stopwatch]::StartNew()
        }
    }

    function GetCIEMAzureScanServiceCache {
        param(
            [Parameter(Mandatory)]
            [string[]]$NeedKeys,
            [Parameter(Mandatory)]
            [string[]]$SubscriptionIds,
            [Parameter(Mandatory)]
            [bool]$HasDiscoveryData,
            [Parameter(Mandatory)]
            [hashtable]$ServiceData,
            [Parameter(Mandatory)]
            [hashtable]$ServiceErrors,
            [Parameter(Mandatory)]
            [hashtable]$ServiceStarted
        )

        $ErrorActionPreference = 'Stop'

        if (-not $HasDiscoveryData) {
            foreach ($serviceName in (($NeedKeys | ForEach-Object { ($_ -split ':', 2)[0] }) | Select-Object -Unique)) {
                $titleCased = $serviceName.Substring(0, 1).ToUpper() + $serviceName.Substring(1)
                EnsureServiceBucket -ServiceData $ServiceData -ServiceErrors $ServiceErrors -ServiceStarted $ServiceStarted -ServiceName $titleCased
                $ServiceErrors[$titleCased] += 'No discovery data available — run Start-CIEMAzureDiscovery first'
            }
        }
        else {
            # Dispatch into per-prefix helpers. Each helper no-ops when no need keys
            # in its namespace are present, so unconditional invocation is fine.
            GetCIEMEntraNeeds `
                -NeedKeys $NeedKeys `
                -ServiceData $ServiceData `
                -ServiceErrors $ServiceErrors `
                -ServiceStarted $ServiceStarted

            GetCIEMIAMNeeds `
                -NeedKeys $NeedKeys `
                -SubscriptionIds $SubscriptionIds `
                -ServiceData $ServiceData `
                -ServiceErrors $ServiceErrors `
                -ServiceStarted $ServiceStarted

            # Reject any need keys that aren't claimed by either helper (fail-fast on
            # unknown top-level prefixes).
            $unknownPrefixes = @(
                $NeedKeys | Where-Object { $_ -notlike 'entra:*' -and $_ -notlike 'iam:*' }
            )
            if ($unknownPrefixes.Count -gt 0) {
                throw "Unknown data need '$($unknownPrefixes[0])'."
            }
        }

        $caches = @()
        foreach ($serviceName in $ServiceData.Keys) {
            $duration = if ($ServiceStarted.ContainsKey($serviceName)) {
                $ServiceStarted[$serviceName].Stop()
                $ServiceStarted[$serviceName].Elapsed
            }
            else {
                [timespan]::Zero
            }

            $caches += [CIEMServiceCache]@{
                ServiceName = $serviceName
                Success = @($ServiceErrors[$serviceName]).Count -eq 0
                Duration = $duration
                CacheData = $ServiceData[$serviceName]
                Errors = @($ServiceErrors[$serviceName])
                Warnings = @()
                Output = @()
            }
        }

        $caches
    }

    function ConvertToCIEMScanResultObject {
        param(
            [Parameter(Mandatory)]
            [object]$ResultData
        )

        $ErrorActionPreference = 'Stop'

        [CIEMScanResult]::Create(
            $ResultData.Check,
            $ResultData.Status.ToString(),
            $ResultData.StatusExtended,
            $ResultData.ResourceId,
            $ResultData.ResourceName,
            $ResultData.Location
        )
    }

    Write-CIEMLog -Message "Invoke-CIEMScan called: Provider=[$($Provider -join ',')], CheckId=[$($CheckId -join ',')], Service=[$($Service -join ',')]" -Severity INFO -Component 'Scan'

    $providerCount = $Provider.Count
    $progressActivity = "CIEM Scan ($($Provider -join ', '))"

    $providersToConnect = @($Provider | Where-Object { -not $script:AuthContext[$_] })
    if ($providersToConnect.Count -gt 0) {
        Write-Progress -Activity $progressActivity -Status "Connecting to $($providersToConnect -join ', ')..." -PercentComplete 0
        $connectResult = Connect-CIEM -Provider $providersToConnect
        $connectLookup = @{}
        foreach ($providerResult in $connectResult.Providers) {
            $connectLookup[$providerResult.Provider] = $providerResult
        }
    }
    else {
        $connectLookup = @{}
    }

    $providerIdx = 0
    foreach ($providerName in $Provider) {
        $providerIdx++
        $providerResult = if ($connectLookup.ContainsKey($providerName)) {
            $connectLookup[$providerName]
        }
        else {
            [pscustomobject]@{
                Provider = $providerName
                Status = 'AlreadyConnected'
                Message = 'Already authenticated.'
            }
        }

        if ($providerResult.Status -notin @('Connected', 'AlreadyConnected')) {
            $failMsg = if ($providerResult) { $providerResult.Message } else { 'No connection result returned' }
            Write-Warning "Skipping $providerName (connection failed): $failMsg"

            $skippedChecks = @(Get-CIEMCheck -Provider $providerName)
            if ($CheckId) { $skippedChecks = @($skippedChecks | Where-Object { $CheckId -contains $_.Id }) }
            if ($Service) { $skippedChecks = @($skippedChecks | Where-Object { $Service -contains $_.Service.ToString() }) }

            foreach ($skippedCheck in $skippedChecks) {
                [CIEMScanResult]::Create($skippedCheck, 'SKIPPED', "Provider $providerName failed to connect: $failMsg", 'N/A', 'N/A')
            }
            continue
        }

        $authContext = $script:AuthContext[$providerName]
        $subscriptionIds = @(if ($authContext -and $authContext.PSObject.Properties.Name -contains 'SubscriptionIds') { $authContext.SubscriptionIds } else { @() })

        Write-Verbose "[$providerName] Authenticated as: $($authContext.AccountId) ($($authContext.AccountType))"

        Sync-CIEMCheckCatalog -Provider $providerName

        $providerModuleRoot = switch ($providerName) {
            'Azure' { Join-Path $script:ModuleRoot 'modules/Azure' }
            'AWS' { Join-Path $script:ModuleRoot 'modules/AWS' }
            default { $null }
        }
        $checkScriptsPath = if ($providerModuleRoot) { Join-Path $providerModuleRoot 'Checks' } else { $null }
        $checkScripts = @(Get-ChildItem -Path "$checkScriptsPath/*.ps1" -ErrorAction SilentlyContinue)

        if ($checkScripts.Count -eq 0) {
            Write-Warning "[$providerName] No check scripts found in $checkScriptsPath — skipping provider."
            continue
        }

        foreach ($scriptFile in $checkScripts) {
            . $scriptFile.FullName
        }

        $dbChecks = @(Get-CIEMCheck -Provider $providerName)
        $dbChecksByScript = @{}
        foreach ($dbCheck in $dbChecks) {
            if ($dbCheck.CheckScript) {
                $dbChecksByScript[$dbCheck.CheckScript] = $dbCheck
            }
        }

        if (-not $CheckId -and -not $Service) {
            $missingMetadataScripts = @($checkScripts | Where-Object { -not $dbChecksByScript.ContainsKey($_.Name) })
            if ($missingMetadataScripts.Count -gt 0) {
                $missingNames = $missingMetadataScripts.Name -join ', '
                throw "[$providerName] Check metadata missing for script(s): $missingNames"
            }
        }

        # Use [List[object]] (not [List[CIEMCheck]]) — module classes get a fresh
        # dynamic assembly per Import-Module, so a strongly-typed list created here
        # may receive a CIEMCheck instance from a different assembly version when PSU
        # has accumulated multiple module loads, causing List<T>.Add() to fail
        # overload resolution with "Cannot find an overload for Add and the argument
        # count: 1".
        $selectedChecks = [System.Collections.Generic.List[object]]::new()
        foreach ($dbCheck in $dbChecks) {
            if ($CheckId -and $CheckId -notcontains $dbCheck.Id) {
                continue
            }
            if ($Service -and $Service -notcontains $dbCheck.Service.ToString()) {
                continue
            }
            if ($dbCheck.Disabled) {
                Write-Verbose "[$providerName] Skipping disabled check: $($dbCheck.Id)"
                continue
            }

            $scriptPath = Join-Path $checkScriptsPath $dbCheck.CheckScript
            if (-not (Test-Path $scriptPath)) {
                throw "[$providerName] Check '$($dbCheck.Id)' references missing script '$($dbCheck.CheckScript)'."
            }

            $functionName = $dbCheck.CheckScript -replace '\.ps1$', ''
            if (-not (Get-Command -Name $functionName -ErrorAction SilentlyContinue)) {
                throw "[$providerName] Script '$($dbCheck.CheckScript)' did not load function '$functionName'."
            }

            if (-not $dbCheck.DataNeeds) {
                throw "[$providerName] Check '$($dbCheck.Id)' is missing data_needs metadata."
            }
            if (@($dbCheck.DataNeeds).Count -eq 0) {
                throw "[$providerName] Check '$($dbCheck.Id)' must declare at least one data need."
            }

            foreach ($needKey in @($dbCheck.DataNeeds)) {
                if ($needKey -cne $needKey.ToLowerInvariant()) {
                    throw "[$providerName] Check '$($dbCheck.Id)' declares non-canonical data need '$needKey'."
                }
            }

            # Pre-validate severity BEFORE parallel dispatch. The cast must succeed on
            # the main thread so we get a meaningful error, not a cross-runspace failure.
            try {
                $null = [CIEMCheckSeverity]$dbCheck.Severity
            }
            catch {
                throw "[$providerName] Check '$($dbCheck.Id)' has invalid severity '$($dbCheck.Severity)': $($_.Exception.Message)"
            }

            $selectedChecks.Add((ConvertToCIEMCheckObject -CheckData $dbCheck))
        }

        if ($selectedChecks.Count -eq 0) {
            Write-Verbose "[$providerName] No checks to execute after filtering; skipping provider."
            continue
        }

        $needKeys = @($selectedChecks | ForEach-Object { $_.DataNeeds } | Select-Object -Unique)
        $statusText = "Scanning $providerName... ($providerIdx of $providerCount providers)"
        Write-Progress -Activity $progressActivity -Status $statusText -PercentComplete ([math]::Floor((($providerIdx - 1) / $providerCount) * 80 + 5))

        $serviceCacheLookup = @{}
        switch ($providerName) {
            'Azure' {
                $latestCompleted = @(Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last 1)
                $latestPartial = @(Get-CIEMAzureDiscoveryRun -Status 'Partial' -Last 1)
                $hasDiscoveryData = ($latestCompleted.Count -gt 0) -or ($latestPartial.Count -gt 0)

                $azureServiceData = @{}
                $azureServiceErrors = @{}
                $azureServiceStarted = @{}

                $azureCaches = @(GetCIEMAzureScanServiceCache `
                    -NeedKeys $needKeys `
                    -SubscriptionIds $subscriptionIds `
                    -HasDiscoveryData $hasDiscoveryData `
                    -ServiceData $azureServiceData `
                    -ServiceErrors $azureServiceErrors `
                    -ServiceStarted $azureServiceStarted)

                foreach ($cache in $azureCaches) {
                    $serviceCacheLookup[$cache.ServiceName] = $cache
                    Write-Verbose "[$providerName] Loaded $($cache.ServiceName) needs in $([math]::Round($cache.Duration.TotalSeconds, 2))s"
                }
            }
            'AWS' {
                $servicesToInit = @(
                    @($selectedChecks | ForEach-Object { $_.Service.ToString() }) +
                    @($selectedChecks | Where-Object { $_.DependsOn } | ForEach-Object { $_.DependsOn }) |
                    Select-Object -Unique
                )
                $sw = [Diagnostics.Stopwatch]::new()
                foreach ($svcName in $servicesToInit) {
                    $sw.Restart()
                    $getFn = "Get-CIEMAWS${svcName}Data"
                    if (-not (Get-Command $getFn -ErrorAction SilentlyContinue)) {
                        continue
                    }
                    try {
                        $serviceCacheLookup[$svcName] = [CIEMServiceCache]@{
                            ServiceName = $svcName
                            Success = $true
                            Duration = $sw.Elapsed
                            CacheData = (& $getFn)
                            Errors = @()
                            Warnings = @()
                            Output = @()
                        }
                    }
                    catch {
                        $serviceCacheLookup[$svcName] = [CIEMServiceCache]@{
                            ServiceName = $svcName
                            Success = $false
                            Duration = $sw.Elapsed
                            CacheData = @{}
                            Errors = @($_.Exception.Message)
                            Warnings = @()
                            Output = @()
                        }
                    }
                }
            }
        }

        $workItems = foreach ($check in $selectedChecks) {
            $functionName = $check.CheckScript -replace '\.ps1$', ''
            $neededServices = @($check.Service.ToString())
            if ($check.DependsOn) {
                $neededServices += $check.DependsOn
            }
            [pscustomobject]@{
                Check = $check
                FunctionName = $functionName
                ProviderName = $providerName
                ServiceCache = @($neededServices | ForEach-Object {
                    if ($serviceCacheLookup.ContainsKey($_)) {
                        $serviceCacheLookup[$_]
                    }
                } | Where-Object { $_ })
            }
        }

        $parallelResults = @(InvokeCIEMParallelForEach -InputObject $workItems -ThrottleLimit $script:CIEMParallelThrottleLimitScan -ScriptBlock {
            param($workItem)

            $check = [CIEMCheck]::new()
            foreach ($property in 'Id', 'Provider', 'Service', 'Title', 'Description', 'Risk', 'RelatedUrl', 'CheckScript', 'DependsOn', 'DataNeeds', 'Disabled') {
                if ($workItem.Check.PSObject.Properties.Name -contains $property) {
                    $check.$property = $workItem.Check.$property
                }
            }
            $check.Severity = [CIEMCheckSeverity]$workItem.Check.Severity

            $remediation = [CIEMCheckRemediation]::new()
            if ($workItem.Check.Remediation) {
                $remediation.Text = $workItem.Check.Remediation.Text
                $remediation.Url = $workItem.Check.Remediation.Url
            }
            $check.Remediation = $remediation

            $permissions = [CIEMCheckPermissions]::new()
            if ($workItem.Check.Permissions) {
                $permissions.Graph = @($workItem.Check.Permissions.Graph)
                $permissions.ARM = @($workItem.Check.Permissions.ARM)
                $permissions.KeyVaultDataPlane = @($workItem.Check.Permissions.KeyVaultDataPlane)
                $permissions.IAM = @($workItem.Check.Permissions.IAM)
            }
            $check.Permissions = $permissions

            $serviceCaches = @(
                foreach ($cacheData in @($workItem.ServiceCache)) {
                    [CIEMServiceCache]@{
                        ServiceName = $cacheData.ServiceName
                        Success = [bool]$cacheData.Success
                        Duration = $cacheData.Duration
                        CacheData = $cacheData.CacheData
                        Errors = @($cacheData.Errors)
                        Warnings = @($cacheData.Warnings)
                        Output = @($cacheData.Output)
                    }
                }
            )

            Invoke-CIEMCheck -Check $check -ServiceCache $serviceCaches -FunctionName $workItem.FunctionName -ProviderName $workItem.ProviderName
        })

        foreach ($parallelResult in $parallelResults) {
            if (-not $parallelResult.Success) {
                $checkId = if ($parallelResult.Input -and $parallelResult.Input.Check) { $parallelResult.Input.Check.Id } else { 'unknown-check' }
                throw "[$providerName] Check '$checkId' failed: $($parallelResult.Error)"
            }

            foreach ($result in @($parallelResult.Result)) {
                ConvertToCIEMScanResultObject -ResultData $result
            }
        }

        Write-Verbose "[$providerName] Provider scan complete."
    }

    Write-Progress -Activity $progressActivity -Completed
}
