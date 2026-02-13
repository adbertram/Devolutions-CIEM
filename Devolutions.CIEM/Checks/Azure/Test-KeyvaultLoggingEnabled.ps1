function Test-KeyvaultLoggingEnabled {
    <#
    .SYNOPSIS
        Tests that diagnostic logging is enabled for Azure Key Vaults.

    .DESCRIPTION
        Verifies that Azure Key Vaults have diagnostic settings configured to enable
        audit logging. Logging is essential for monitoring access patterns, detecting
        unauthorized access attempts, and maintaining compliance audit trails.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'KeyVault' }).CacheData

    foreach ($subscriptionId in $svc.Keys) {
        $kvData = $svc[$subscriptionId]

        foreach ($vault in $kvData.KeyVaults) {
            $diagnosticSettings = $kvData.DiagnosticSettings[$vault.name]
            $hasLogging = $false
            $logDestinations = @()

            if ($diagnosticSettings) {
                foreach ($setting in $diagnosticSettings) {
                    # Strict mode safe property access
                    $logs = if ($setting.PSObject.Properties['properties'] -and
                        $setting.properties.PSObject.Properties['logs']) {
                        $setting.properties.logs
                    }
                    else {
                        @()
                    }

                    # Prowler requires BOTH 'audit' AND 'allLogs' category groups to be enabled
                    $hasAudit = $false
                    $hasAllLogs = $false
                    foreach ($log in $logs) {
                        if ($log.categoryGroup -eq 'audit' -and $log.enabled -eq $true) {
                            $hasAudit = $true
                        }
                        if ($log.categoryGroup -eq 'allLogs' -and $log.enabled -eq $true) {
                            $hasAllLogs = $true
                        }
                    }

                    if ($hasAudit -and $hasAllLogs) {
                        $hasLogging = $true
                        if ($setting.properties.PSObject.Properties['workspaceId'] -and $setting.properties.workspaceId) {
                            $logDestinations += 'Log Analytics'
                        }
                        if ($setting.properties.PSObject.Properties['storageAccountId'] -and $setting.properties.storageAccountId) {
                            $logDestinations += 'Storage Account'
                        }
                        if ($setting.properties.PSObject.Properties['eventHubAuthorizationRuleId'] -and $setting.properties.eventHubAuthorizationRuleId) {
                            $logDestinations += 'Event Hub'
                        }
                    }
                }
            }

            $status = if ($hasLogging) { 'PASS' } else { 'FAIL' }
            $message = if ($hasLogging) {
                $destinations = ($logDestinations | Select-Object -Unique) -join ', '
                "Vault '$($vault.name)' has diagnostic logging enabled. Destinations: $destinations"
            }
            else {
                "Vault '$($vault.name)' does not have diagnostic logging enabled. Enable AuditEvent logging to monitor vault access."
            }

            [CIEMScanResult]::Create($Check, $status, $message, $vault.id, $vault.name, $vault.location)
        }
    }
}
