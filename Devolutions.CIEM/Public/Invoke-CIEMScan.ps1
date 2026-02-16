function Invoke-CIEMScan {
    <#
    .SYNOPSIS
        Executes CIEM security checks against cloud resources.

    .DESCRIPTION
        Main entry point for running CIEM security scans. Authenticates to the
        specified cloud provider, initializes service data, and executes selected
        checks in parallel.

        Returns an array of finding objects with pass/fail/manual/skipped status.

    .PARAMETER Provider
        Cloud provider to scan. Supports 'Azure' and 'AWS'.

    .PARAMETER CheckId
        Optional array of check IDs to run. If not specified, runs all checks.

    .PARAMETER Service
        Optional service filter. Only runs checks for specified service(s).

    .PARAMETER ThrottleLimit
        Maximum parallel check execution threads. Default from config (10).

    .PARAMETER IncludePassed
        Whether to include passed checks in results. Default is false.

    .OUTPUTS
        [CIEMScanResult[]] Array of finding objects with properties:
        - Check: CIEMCheck object with Id, Severity, Title, etc.
        - Status: PASS, FAIL, MANUAL, or SKIPPED
        - StatusExtended: Detailed explanation
        - ResourceId: Azure resource ID
        - ResourceName: Resource display name
        - Location: Resource location

    .EXAMPLE
        $findings = Invoke-CIEMScan
        # Runs all 46 checks

    .EXAMPLE
        $findings = Invoke-CIEMScan -CheckId 'entra_security_defaults_enabled'
        # Runs single check

    .EXAMPLE
        $findings = Invoke-CIEMScan -Service Entra -Verbose
        # Runs all Entra checks with verbose output

    .EXAMPLE
        $findings = Invoke-CIEMScan | Where-Object Status -eq 'FAIL'
        # Get only failed findings
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ThrottleLimit', Justification = 'Reserved for future parallel implementation')]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter()]
        [string]$Provider = 'Azure',

        [Parameter()]
        [string[]]$CheckId,

        [Parameter()]
        [string[]]$Service,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$ThrottleLimit = $(if ($script:Config.scan.throttleLimit) { $script:Config.scan.throttleLimit } else { 10 }),

        [Parameter()]
        [switch]$IncludePassed
    )

    $ErrorActionPreference = 'Stop'

    # Note: ThrottleLimit reserved for future parallel implementation

    # Determine services for ScanRun (use Service param if provided, otherwise all for this provider)
    $providerServices = @(Get-CIEMProviderService -Provider $Provider | Select-Object -ExpandProperty Name)
    $scanServices = if ($Service) { $Service } else { $providerServices }

    # Validate that requested services exist for this provider
    if ($Service) {
        $invalidServices = $Service | Where-Object { $_ -notin $providerServices }
        if ($invalidServices) {
            throw "Invalid service(s) for provider $Provider`: $($invalidServices -join ', '). Valid services: $($providerServices -join ', ')"
        }
    }

    # Create and persist ScanRun at start
    $scanRun = New-CIEMScanRun -Provider $Provider -Services $scanServices -IncludePassed $IncludePassed.IsPresent
    Save-CIEMScanRun -ScanRun $scanRun
    Write-Verbose "Started ScanRun: $($scanRun.Id)"

    # Collection for all findings (for ScanRun attachment)
    $allFindings = [System.Collections.ArrayList]::new()

    Write-Verbose "Starting CIEM scan for provider: $Provider"
    $progressActivity = "CIEM Scan ($Provider)"

    try {
        # Connect to provider (handles all auth internally, returns context)
        Write-Progress -Activity $progressActivity -Status "Connecting to $Provider..." -PercentComplete 0
        $connectResult = Connect-CIEM -Provider $Provider -Force
        $providerResult = $connectResult.Providers | Where-Object { $_.Provider -eq $Provider }

        if ($providerResult.Status -ne 'Connected') {
            throw "Failed to connect to ${Provider}: $($providerResult.Message)"
        }

        $authContext = $script:AuthContext[$Provider.ToString()]
        # SubscriptionIds/TenantId are Azure-specific; guard with property check to avoid errors on AWS
        $subscriptionIds = @(if ($authContext.PSObject.Properties['SubscriptionIds']) { $authContext.SubscriptionIds } else { @() })

        Write-Verbose "Authenticated as: $($authContext.AccountId) ($($authContext.AccountType))"
        if ($authContext.PSObject.Properties['TenantId']) {
            Write-Verbose "Tenant: $($authContext.TenantId)"
        }
        Write-Verbose "Subscriptions: $($subscriptionIds.Count)"

        # Step 2: Initialize services via CIEMServiceCache orchestrator
        $servicesToInit = if ($Service) { $Service } else { $providerServices }
        $providerObj = Get-CIEMProvider -Name $Provider
        $serviceCacheLookup = @{}

        Write-Progress -Activity $progressActivity -Status "Initializing services..." -PercentComplete 5

        switch ($Provider) {
            'Azure' {
                $svcIndex = 0
                Initialize-CIEMServiceCache -Provider $providerObj -Name $servicesToInit -SubscriptionIds $subscriptionIds | ForEach-Object {
                    $svcIndex++
                    $svcPct = 5 + [math]::Floor(($svcIndex / @($servicesToInit).Count) * 15)
                    Write-Progress -Activity $progressActivity -Status "Initializing services..." -CurrentOperation $_.ServiceName -PercentComplete $svcPct
                    $serviceCacheLookup[$_.ServiceName] = $_
                    if ($_.Success) {
                        Write-Verbose "Initialized $($_.ServiceName) in $([math]::Round($_.Duration.TotalSeconds, 2))s"
                    } else {
                        Write-Warning "Failed to initialize $($_.ServiceName): $($_.Errors -join '; ')"
                    }
                    foreach ($w in $_.Warnings) {
                        Write-Warning "[$($_.ServiceName)] $w"
                    }
                }
            }
            'AWS' {
                # AWS checks are stubs (MANUAL status) - no service initialization needed
                Write-Verbose "AWS provider: skipping service initialization (all checks return MANUAL)"
            }
        }

        # Step 3: Load check metadata via Get-CIEMCheck (handles filtering)
        $getCheckParams = @{ Provider = $Provider }
        if ($CheckId -and $CheckId.Count -eq 1) { $getCheckParams.CheckId = $CheckId[0] }
        if ($Service -and $Service.Count -eq 1) { $getCheckParams.Service = $Service[0] }
        $checks = Get-CIEMCheck @getCheckParams

        # Apply multi-value filters that Get-CIEMCheck doesn't support
        if ($CheckId -and $CheckId.Count -gt 1) {
            $checks = $checks | Where-Object { $CheckId -contains $_.Id }
        }
        if ($Service -and $Service.Count -gt 1) {
            $checks = $checks | Where-Object { $Service -contains $_.Service.ToString() }
        }

        Write-Verbose "Checks to execute: $(@($checks).Count)"

        # Step 5: Load check scripts
        $checkScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath "../Checks/$Provider"
        $checkScripts = Get-ChildItem -Path "$checkScriptsPath/*.ps1"

        if (-not $checkScripts -or $checkScripts.Count -eq 0) {
            throw "No check scripts found in $checkScriptsPath"
        }

        # Dot-source all check scripts
        foreach ($script in $checkScripts) {
            . $script.FullName
        }

        # Build a hashtable of available check functions
        $availableFunctions = @{}
        foreach ($check in $checks) {
            $functionName = $check.CheckScript -replace '\.ps1$', ''
            if (Get-Command -Name $functionName -ErrorAction SilentlyContinue) {
                $availableFunctions[$check.Id] = $functionName
            }
            else {
                Write-Warning "Check function not found: $functionName for check $($check.Id)"
            }
        }

        # Step 6: Execute checks and stream findings to pipeline
        # Note: ForEach-Object -Parallel creates new runspaces, so we need to pass service data
        # For simplicity in V1, we'll use sequential execution with the singleton pattern
        # A more robust parallel implementation would serialize service data

        Write-Verbose "Executing checks..."
        $findingCount = 0
        $statusCounts = @{ PASS = 0; FAIL = 0; MANUAL = 0; SKIPPED = 0 }
        $checkIndex = 0
        $totalChecks = @($checks).Count

        foreach ($check in $checks) {
            $checkIndex++
            $checkPct = 20 + [math]::Floor(($checkIndex / $totalChecks) * 80)
            Write-Progress -Activity $progressActivity -Status "Running check $checkIndex of $totalChecks" -CurrentOperation $check.Title -PercentComplete $checkPct
            $functionName = $availableFunctions[$check.Id]

            if (-not $functionName) {
                Write-Verbose "Skipping check $($check.Id) - function not available"
                $statusCounts['SKIPPED']++
                $findingCount++
                $finding = [CIEMScanResult]::Create($check, 'SKIPPED', 'Check function not implemented', 'N/A', 'N/A')
                [void]$allFindings.Add($finding)
                $finding
            }
            else {
                Write-Verbose "Running check: $($check.Id)"

                try {
                    # Build service cache array for this check
                    $checkService = $check.Service.ToString()
                    $neededServices = @($checkService)
                    if ($check.DependsOn) { $neededServices += $check.DependsOn }

                    $checkCaches = @($neededServices | ForEach-Object {
                        if ($serviceCacheLookup.ContainsKey($_)) { $serviceCacheLookup[$_] }
                    } | Where-Object { $_ })

                    # Auto-skip if any required service failed to initialize
                    # (empty CacheData + StrictMode causes dot-notation property access to throw)
                    $failedServices = @($checkCaches | Where-Object { -not $_.Success })
                    if ($failedServices) {
                        $failedDetails = @($failedServices | ForEach-Object {
                            $svcName = $_.ServiceName
                            $errorDetail = if ($_.Errors -and $_.Errors.Count -gt 0) { $_.Errors[0] } else { 'unknown error' }
                            "$svcName`: $errorDetail"
                        })
                        $failedMessage = "Required service(s) unavailable: $($failedDetails -join '; ')"
                        Write-Verbose "Skipping check $($check.Id) - service(s) failed to initialize: $failedMessage"
                        $statusCounts['SKIPPED']++
                        $findingCount++
                        $finding = [CIEMScanResult]::Create($check, 'SKIPPED', $failedMessage, 'N/A', 'N/A')
                        [void]$allFindings.Add($finding)
                        $finding
                        continue
                    }

                    # Execute check and stream each finding to the pipeline
                    $checkFindingCount = 0
                    foreach ($finding in (& $functionName -Check $check -ServiceCache $checkCaches)) {
                        $checkFindingCount++
                        $findingCount++
                        # Cast enum to string for hashtable key lookup (.ContainsKey doesn't coerce enums)
                        $statusKey = [string]$finding.Status
                        if ($statusCounts.ContainsKey($statusKey)) {
                            $statusCounts[$statusKey]++
                        }
                        [void]$allFindings.Add($finding)
                        $finding
                    }

                    # If a check produced zero findings, emit SKIPPED (e.g., no subscriptions available)
                    if ($checkFindingCount -eq 0) {
                        Write-Verbose "Check $($check.Id) produced no findings - marking as SKIPPED"
                        $statusCounts['SKIPPED']++
                        $findingCount++
                        $finding = [CIEMScanResult]::Create($check, 'SKIPPED', 'Check produced no results - required data may be unavailable (e.g., no accessible subscriptions)', 'N/A', 'N/A')
                        [void]$allFindings.Add($finding)
                        $finding
                    }
                }
                catch {
                    # Default to continue on individual check failures
                    $continueOnError = if ($null -ne $script:Config -and $null -ne $script:Config.scan) { $script:Config.scan.continueOnError } else { $true }
                    if ($continueOnError) {
                        Write-Warning "Check $($check.Id) failed: $($_.Exception.Message)"
                        $statusCounts['SKIPPED']++
                        $findingCount++
                        $finding = [CIEMScanResult]::Create($check, 'SKIPPED', "Check execution failed: $($_.Exception.Message)", 'N/A', 'N/A')
                        [void]$allFindings.Add($finding)
                        $finding
                    }
                    else {
                        throw
                    }
                }
            }
        }

        # Step 7: Log summary (findings already streamed to pipeline)
        Write-Verbose "Scan complete. Total findings: $findingCount"
        $statusSummary = $statusCounts.GetEnumerator() | Where-Object { $_.Value -gt 0 } | ForEach-Object { "$($_.Key): $($_.Value)" }
        Write-Verbose "Status summary: $($statusSummary -join ', ')"

        # Update ScanRun with results and mark as completed
        Write-Progress -Activity $progressActivity -Completed
        Update-CIEMScanRun -ScanRun $scanRun -Status Completed -ScanResults @($allFindings) | Out-Null
        Write-Verbose "ScanRun completed: $($scanRun.Id)"
    }
    catch {
        # Update ScanRun with failure status
        Write-Progress -Activity $progressActivity -Completed
        Update-CIEMScanRun -ScanRun $scanRun -Status Failed -ScanResults @($allFindings) -ErrorMessage $_.Exception.Message | Out-Null
        Write-Verbose "ScanRun failed: $($scanRun.Id) - $($_.Exception.Message)"
        throw
    }
}
