function Invoke-CIEMScan {
    <#
    .SYNOPSIS
        Executes CIEM security checks against cloud resources.

    .DESCRIPTION
        Main entry point for running CIEM security scans. Authenticates to the
        specified cloud providers, initializes service data, and executes selected
        checks sequentially, interleaving findings to the pipeline as each check
        completes.

        When -Provider is omitted, all enabled providers are scanned. If one
        provider fails to connect, its checks are marked SKIPPED and scanning
        continues with remaining providers.

    .PARAMETER Provider
        One or more cloud providers to scan ('Azure', 'AWS').
        Omit to scan all enabled providers.

    .PARAMETER CheckId
        Optional array of check IDs to run. If not specified, runs all checks.

    .PARAMETER Service
        Optional service filter. Only runs checks for specified service(s).
        Applied globally — providers that do not have the service are skipped silently.

    .PARAMETER ThrottleLimit
        Reserved for future parallel implementation.

    .PARAMETER IncludePassed
        Whether to include passed checks in results. Default is false.

    .OUTPUTS
        [CIEMScanResult[]] Array of finding objects streamed as each check completes.

    .EXAMPLE
        $findings = Invoke-CIEMScan
        # Scans all enabled providers

    .EXAMPLE
        $findings = Invoke-CIEMScan -Provider 'Azure'
        # Scans Azure only

    .EXAMPLE
        $findings = Invoke-CIEMScan -Provider @('Azure', 'AWS') -Service 'Entra'
        # Scans the Entra service on Azure; AWS is skipped silently (no Entra service)

    .EXAMPLE
        $findings = Invoke-CIEMScan | Where-Object Status -eq 'FAIL'
        # Get only failed findings
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ThrottleLimit', Justification = 'Reserved for future parallel implementation')]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter()]
        [string[]]$Provider,

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

    # Resolve providers: default to all enabled when not specified
    if (-not $Provider -or $Provider.Count -eq 0) {
        $Provider = @(Get-CIEMProvider | Where-Object Enabled | Select-Object -ExpandProperty Name)
        if ($Provider.Count -eq 0) {
            throw "No enabled providers configured. Use New-CIEMProvider to add providers."
        }
        Write-Verbose "No -Provider specified; scanning all enabled providers: $($Provider -join ', ')"
    }

    $providerCount = $Provider.Count

    # Determine the union of all services across requested providers
    $allProviderServices = @(foreach ($p in $Provider) {
        Get-CIEMProviderService -Provider $p | Select-Object -ExpandProperty Name
    })

    # Validate -Service if specified: at least one provider must have each requested service
    if ($Service) {
        $invalidServices = $Service | Where-Object { $_ -notin $allProviderServices }
        if ($invalidServices) {
            throw "Requested service(s) not available in any specified provider: $($invalidServices -join ', '). Available: $($allProviderServices -join ', ')"
        }
    }

    # Services for the ScanRun record: the union of what will actually be scanned
    $scanServices = if ($Service) { $Service } else { $allProviderServices | Select-Object -Unique }

    # Create and persist ScanRun at start (single run for all providers)
    $scanRun = New-CIEMScanRun -Providers $Provider -Services $scanServices -IncludePassed $IncludePassed.IsPresent
    Save-CIEMScanRun -ScanRun $scanRun
    Write-Verbose "Started ScanRun: $($scanRun.Id) for providers: $($Provider -join ', ')"

    # Collection for all findings (for ScanRun attachment at end)
    $allFindings = [System.Collections.ArrayList]::new()

    $progressActivity = "CIEM Scan ($($Provider -join ', '))"

    try {
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
                    $finding = [CIEMScanResult]::Create($skippedCheck, 'SKIPPED', "Provider $providerName failed to connect: $failMsg", 'N/A', 'N/A')
                    [void]$allFindings.Add($finding)
                    $finding
                }
                continue
            }

            $authContext    = $script:AuthContext[$providerName.ToString()]
            $subscriptionIds = @(if ($authContext.PSObject.Properties['SubscriptionIds']) { $authContext.SubscriptionIds } else { @() })

            Write-Verbose "[$providerName] Authenticated as: $($authContext.AccountId) ($($authContext.AccountType))"

            # Determine services for this provider
            $thisProviderServices = @(Get-CIEMProviderService -Provider $providerName | Select-Object -ExpandProperty Name)
            $servicesToInit = @(if ($Service) {
                $Service | Where-Object { $_ -in $thisProviderServices }
            } else {
                $thisProviderServices
            })

            if ($servicesToInit.Count -eq 0) {
                Write-Verbose "[$providerName] No matching services for the requested filter; skipping provider."
                continue
            }

            # Initialize services for this provider
            $providerObj        = Get-CIEMProvider -Name $providerName
            $serviceCacheLookup = @{}
            $statusText         = "Scanning $providerName... ($providerIdx of $providerCount providers)"
            Write-Progress -Activity $progressActivity -Status $statusText -PercentComplete ([math]::Floor((($providerIdx - 1) / $providerCount) * 80 + 5))

            switch ($providerName) {
                'Azure' {
                    $svcIndex = 0
                    Initialize-CIEMServiceCache -Provider $providerObj -Name $servicesToInit -SubscriptionIds $subscriptionIds | ForEach-Object {
                        $svcIndex++
                        $serviceCacheLookup[$_.ServiceName] = $_
                        if ($_.Success) {
                            Write-Verbose "[$providerName] Initialized $($_.ServiceName) in $([math]::Round($_.Duration.TotalSeconds, 2))s"
                        } else {
                            Write-Warning "[$providerName] Failed to initialize $($_.ServiceName): $($_.Errors -join '; ')"
                        }
                        foreach ($w in $_.Warnings) { Write-Warning "[$providerName][$($_.ServiceName)] $w" }
                    }
                }
                'AWS' {
                    $svcIndex = 0
                    Initialize-CIEMServiceCache -Provider $providerObj -Name $servicesToInit | ForEach-Object {
                        $svcIndex++
                        if ($_.Success) {
                            $serviceCacheLookup[$_.ServiceName] = $_
                            Write-Verbose "[$providerName] Initialized $($_.ServiceName) in $([math]::Round($_.Duration.TotalSeconds, 2))s"
                        } elseif ($_.Errors -and $_.Errors[0] -match 'Service script not found') {
                            Write-Verbose "[$providerName] No service script for $($_.ServiceName) — checks will run as stubs"
                        } else {
                            $serviceCacheLookup[$_.ServiceName] = $_
                            Write-Warning "[$providerName] Failed to initialize $($_.ServiceName): $($_.Errors -join '; ')"
                        }
                        foreach ($w in $_.Warnings) { Write-Warning "[$providerName][$($_.ServiceName)] $w" }
                    }
                }
            }

            # Build identity-to-resource relationship graph (if Graph module is available)
            if (Get-Module -ListAvailable -Name 'Devolutions.CIEM.Graph' -ErrorAction SilentlyContinue) {
                try {
                    Import-Module Devolutions.CIEM.Graph -ErrorAction Stop
                    $entraCache = $serviceCacheLookup['Entra']
                    $iamCache = $serviceCacheLookup['IAM']

                    if ($entraCache -and $entraCache.Success) {
                        $graphEntraData = $entraCache.CacheData
                        $graphIAMData = if ($iamCache -and $iamCache.Success) { $iamCache.CacheData } else { @{} }

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

                        # Store graph in PSU cache for UI access (Identity Graph page)
                        $exported = Export-CIEMGraph -Graph $ciemGraph
                        try {
                            Set-PSUCache -Key "CIEM:Graph:$providerName" -Value $exported -Persist -ErrorAction Stop
                            Write-Verbose "[$providerName] Graph stored in PSU cache for UI access"
                        }
                        catch {
                            Write-Warning "[$providerName] Failed to store graph in PSU cache: $($_.Exception.Message)"
                        }
                    }
                    else {
                        Write-Verbose "[$providerName] Skipping graph build — Entra service cache unavailable"
                    }
                }
                catch {
                    Write-Warning "[$providerName] Graph build failed (non-fatal): $($_.Exception.Message)"
                }
            }

            # Load check metadata for this provider
            $getCheckParams = @{ Provider = $providerName }
            if ($CheckId -and $CheckId.Count -eq 1) { $getCheckParams.CheckId = $CheckId[0] }
            if ($Service -and $Service.Count -eq 1)  { $getCheckParams.Service = $Service[0] }
            $checks = Get-CIEMCheck @getCheckParams

            # Apply multi-value filters
            if ($CheckId -and $CheckId.Count -gt 1) { $checks = $checks | Where-Object { $CheckId -contains $_.Id } }
            if ($Service -and $Service.Count -gt 1)  { $checks = $checks | Where-Object { $Service  -contains $_.Service.ToString() } }

            Write-Verbose "[$providerName] Checks to execute: $(@($checks).Count)"

            # Load check scripts for this provider
            $checkScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath "../Checks/$providerName"
            $checkScripts     = Get-ChildItem -Path "$checkScriptsPath/*.ps1" -ErrorAction SilentlyContinue

            if (-not $checkScripts -or $checkScripts.Count -eq 0) {
                Write-Warning "[$providerName] No check scripts found in $checkScriptsPath — skipping provider."
                continue
            }

            foreach ($script in $checkScripts) { . $script.FullName }

            # Build hashtable of available check functions
            $availableFunctions = @{}
            foreach ($check in $checks) {
                $functionName = $check.CheckScript -replace '\.ps1$', ''
                if (Get-Command -Name $functionName -ErrorAction SilentlyContinue) {
                    $availableFunctions[$check.Id] = $functionName
                } else {
                    Write-Warning "[$providerName] Check function not found: $functionName for check $($check.Id)"
                }
            }

            # Execute checks and stream findings interleaved to pipeline
            $checkIndex  = 0
            $totalChecks = @($checks).Count

            foreach ($check in $checks) {
                if ($check.Disabled) {
                    Write-Verbose "[$providerName] Skipping disabled check: $($check.Id)"
                    continue
                }

                $checkIndex++
                $providerBasePct = [math]::Floor((($providerIdx - 1) / $providerCount) * 80 + 5)
                $checkPct        = $providerBasePct + [math]::Floor(($checkIndex / $totalChecks) * (80 / $providerCount))
                Write-Progress -Activity $progressActivity -Status "$statusText - check $checkIndex of $totalChecks" -CurrentOperation $check.Title -PercentComplete $checkPct

                $functionName = $availableFunctions[$check.Id]

                if (-not $functionName) {
                    Write-Verbose "[$providerName] Skipping check $($check.Id) - function not available"
                    $finding = [CIEMScanResult]::Create($check, 'SKIPPED', 'Check function not implemented', 'N/A', 'N/A')
                    [void]$allFindings.Add($finding)
                    $finding
                } else {
                    Write-Verbose "[$providerName] Running check: $($check.Id)"
                    try {
                        $checkService  = $check.Service.ToString()
                        $neededServices = @($checkService)
                        if ($check.DependsOn) { $neededServices += $check.DependsOn }

                        $checkCaches = @($neededServices | ForEach-Object {
                            if ($serviceCacheLookup.ContainsKey($_)) { $serviceCacheLookup[$_] }
                        } | Where-Object { $_ })

                        # Auto-skip if required service failed to initialize
                        $failedServices = @($checkCaches | Where-Object { -not $_.Success })
                        if ($failedServices) {
                            $failedDetails  = @($failedServices | ForEach-Object {
                                $errorDetail = if ($_.Errors -and $_.Errors.Count -gt 0) { $_.Errors[0] } else { 'unknown error' }
                                "$($_.ServiceName): $errorDetail"
                            })
                            $failedMessage = "Required service(s) unavailable: $($failedDetails -join '; ')"
                            Write-Verbose "[$providerName] Skipping check $($check.Id) — service(s) failed: $failedMessage"
                            $finding = [CIEMScanResult]::Create($check, 'SKIPPED', $failedMessage, 'N/A', 'N/A')
                            [void]$allFindings.Add($finding)
                            $finding
                            continue
                        }

                        $invokeParams = @{ Check = $check }
                        if ($checkCaches.Count -gt 0) { $invokeParams.ServiceCache = $checkCaches }

                        $checkFindingCount = 0
                        foreach ($finding in (& $functionName @invokeParams)) {
                            $checkFindingCount++
                            [void]$allFindings.Add($finding)
                            $finding
                        }

                        if ($checkFindingCount -eq 0) {
                            Write-Verbose "[$providerName] Check $($check.Id) produced no findings - marking as SKIPPED"
                            $finding = [CIEMScanResult]::Create($check, 'SKIPPED', 'Check produced no results - required data may be unavailable (e.g., no accessible subscriptions)', 'N/A', 'N/A')
                            [void]$allFindings.Add($finding)
                            $finding
                        }
                    } catch {
                        $continueOnError = if ($null -ne $script:Config -and $null -ne $script:Config.scan) { $script:Config.scan.continueOnError } else { $true }
                        if ($continueOnError) {
                            Write-Warning "[$providerName] Check $($check.Id) failed: $($_.Exception.Message)"
                            $finding = [CIEMScanResult]::Create($check, 'SKIPPED', "Check execution failed: $($_.Exception.Message)", 'N/A', 'N/A')
                            [void]$allFindings.Add($finding)
                            $finding
                        } else {
                            throw
                        }
                    }
                }
            }

            Write-Verbose "[$providerName] Provider scan complete. Findings so far: $($allFindings.Count)"
        }

        # All providers complete
        $totalFindings = $allFindings.Count
        Write-Verbose "Scan complete. Total findings: $totalFindings"
        Write-Progress -Activity $progressActivity -Completed
        Update-CIEMScanRun -ScanRun $scanRun -Status Completed -ScanResults @($allFindings) | Out-Null
        Write-Verbose "ScanRun completed: $($scanRun.Id)"
    } catch {
        Write-Progress -Activity $progressActivity -Completed
        Update-CIEMScanRun -ScanRun $scanRun -Status Failed -ScanResults @($allFindings) -ErrorMessage $_.Exception.Message | Out-Null
        Write-Verbose "ScanRun failed: $($scanRun.Id) - $($_.Exception.Message)"
        throw
    }
}
