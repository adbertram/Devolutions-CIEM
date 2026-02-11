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
        [CIEMCloudProvider]$Provider = 'Azure',

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
    $providerServices = @(Get-CIEMCheckService -CloudProvider $Provider | Select-Object -ExpandProperty Name)
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

    try {
        # Connect to provider (handles all auth internally, returns context)
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

        # Step 2: Initialize services (provider-specific)
        switch ($Provider) {
            'Azure' {
                Write-Verbose "Initializing Entra service..."
                Initialize-EntraService

                Write-Verbose "Initializing IAM service..."
                Initialize-IAMService -SubscriptionIds $subscriptionIds

                Write-Verbose "Initializing KeyVault service..."
                Initialize-KeyVaultService -SubscriptionIds $subscriptionIds

                Write-Verbose "Initializing Storage service..."
                Initialize-StorageService -SubscriptionIds $subscriptionIds
            }
            'AWS' {
                # AWS checks are stubs (MANUAL status) - no service initialization needed
                Write-Verbose "AWS provider: skipping service initialization (all checks return MANUAL)"
            }
        }

        # Step 3: Load check metadata via Get-CIEMCheck (handles filtering)
        $getCheckParams = @{ CloudProvider = $Provider.ToString() }
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

        foreach ($check in $checks) {
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
                    # Execute check and stream each finding to the pipeline
                    $checkFindingCount = 0
                    foreach ($finding in (& $functionName -Check $check)) {
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
        Update-CIEMScanRun -ScanRun $scanRun -Status Completed -ScanResults @($allFindings) | Out-Null
        Write-Verbose "ScanRun completed: $($scanRun.Id)"
    }
    catch {
        # Update ScanRun with failure status
        Update-CIEMScanRun -ScanRun $scanRun -Status Failed -ScanResults @($allFindings) -ErrorMessage $_.Exception.Message | Out-Null
        Write-Verbose "ScanRun failed: $($scanRun.Id) - $($_.Exception.Message)"
        throw
    }
}
