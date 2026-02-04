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

    .OUTPUTS
        [PSCustomObject[]] Array of finding objects with properties:
        - CheckId: The check identifier
        - Status: PASS, FAIL, MANUAL, or SKIPPED
        - StatusExtended: Detailed explanation
        - ResourceId: Azure resource ID
        - ResourceName: Resource display name
        - Location: Resource location
        - Severity: Check severity level

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
    [OutputType([PSCustomObject[]])]
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
        [int]$ThrottleLimit = $(if ($script:Config.scan.throttleLimit) { $script:Config.scan.throttleLimit } else { 10 })
    )

    $ErrorActionPreference = 'Stop'

    # Note: ThrottleLimit reserved for future parallel implementation

    Write-Verbose "Starting CIEM scan for provider: $Provider"

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

    # Step 3: Load check metadata
    $checks = Get-CheckMetadata

    # Step 4: Filter checks
    if ($CheckId) {
        $checks = $checks | Where-Object { $CheckId -contains $_.id }
    }

    if ($Service) {
        $checks = $checks | Where-Object { $Service -contains $_.service }
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
        $functionName = $check.checkScript -replace '\.ps1$', ''
        if (Get-Command -Name $functionName -ErrorAction SilentlyContinue) {
            $availableFunctions[$check.id] = $functionName
        }
        else {
            Write-Warning "Check function not found: $functionName for check $($check.id)"
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
        $functionName = $availableFunctions[$check.id]

        if (-not $functionName) {
            Write-Verbose "Skipping check $($check.id) - function not available"
            $statusCounts['SKIPPED']++
            $findingCount++
            [PSCustomObject]@{
                CheckId        = $check.id
                Status         = 'SKIPPED'
                StatusExtended = 'Check function not implemented'
                ResourceId     = 'N/A'
                ResourceName   = 'N/A'
                Location       = 'N/A'
                Severity       = $check.severity
            }
        }
        else {
            Write-Verbose "Running check: $($check.id)"

            try {
                # Convert check metadata to hashtable for the function
                $checkMetadata = @{
                    id       = $check.id
                    service  = $check.service
                    title    = $check.title
                    severity = $check.severity
                }

                # Execute check and stream each finding to the pipeline
                foreach ($finding in (& $functionName -CheckMetadata $checkMetadata)) {
                    $findingCount++
                    if ($statusCounts.ContainsKey($finding.Status)) {
                        $statusCounts[$finding.Status]++
                    }
                    $finding
                }
            }
            catch {
                if ($script:Config.scan.continueOnError) {
                    Write-Warning "Check $($check.id) failed: $($_.Exception.Message)"
                    $statusCounts['SKIPPED']++
                    $findingCount++
                    [PSCustomObject]@{
                        CheckId        = $check.id
                        Status         = 'SKIPPED'
                        StatusExtended = "Check execution failed: $($_.Exception.Message)"
                        ResourceId     = 'N/A'
                        ResourceName   = 'N/A'
                        Location       = 'N/A'
                        Severity       = $check.severity
                    }
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
}
