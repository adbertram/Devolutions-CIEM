function Invoke-CIEMScan {
    <#
    .SYNOPSIS
        Executes CIEM security checks against Azure resources.

    .DESCRIPTION
        Main entry point for running CIEM security scans. Authenticates to Azure,
        initializes service data, and executes selected checks in parallel.

        Returns an array of finding objects with pass/fail/manual/skipped status.

    .PARAMETER Provider
        Cloud provider to scan. Currently only 'Azure' is supported.

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
        [ValidateSet('Azure')]
        [string]$Provider = 'Azure',

        [Parameter()]
        [string[]]$CheckId,

        [Parameter()]
        [ValidateSet('Entra', 'IAM', 'KeyVault', 'Storage')]
        [string[]]$Service,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$ThrottleLimit = $(if ($script:Config.scan.throttleLimit) { $script:Config.scan.throttleLimit } else { 10 }),

        [Parameter()]
        [switch]$IncludePassed
    )

    $ErrorActionPreference = 'Stop'

    # Note: ThrottleLimit reserved for future parallel implementation

    # Determine services for ScanRun (use Service param if provided, otherwise all)
    $scanServices = if ($Service) { $Service } else { @('Entra', 'IAM', 'KeyVault', 'Storage') }

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

        $authContext = $script:AuthContext[$Provider]
        $subscriptionIds = $authContext.SubscriptionIds

        Write-Verbose "Authenticated as: $($authContext.AccountId) ($($authContext.AccountType))"
        Write-Verbose "Tenant: $($authContext.TenantId)"
        Write-Verbose "Subscriptions: $($subscriptionIds.Count)"

        # Step 2: Initialize services
        Write-Verbose "Initializing Entra service..."
        Initialize-EntraService

        Write-Verbose "Initializing IAM service..."
        Initialize-IAMService -SubscriptionIds $subscriptionIds

        Write-Verbose "Initializing KeyVault service..."
        Initialize-KeyVaultService -SubscriptionIds $subscriptionIds

        Write-Verbose "Initializing Storage service..."
        Initialize-StorageService -SubscriptionIds $subscriptionIds

        # Step 3: Load check metadata via Get-CIEMCheck (handles filtering)
        $getCheckParams = @{}
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
        $checkScriptsPath = Join-Path -Path $PSScriptRoot -ChildPath '../Checks/Azure'
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
                    foreach ($finding in (& $functionName -Check $check)) {
                        $findingCount++
                        if ($statusCounts.ContainsKey($finding.Status)) {
                            $statusCounts[$finding.Status]++
                        }
                        [void]$allFindings.Add($finding)
                        $finding
                    }
                }
                catch {
                    if ($script:Config.scan.continueOnError) {
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
