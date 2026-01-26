function Test-KeyvaultLoggingEnabled {
    <#
    .SYNOPSIS
        Tests that diagnostic logging is enabled for Azure Key Vaults.

    .DESCRIPTION
        Verifies that Azure Key Vaults have diagnostic settings configured to enable
        audit logging. Logging is essential for monitoring access patterns, detecting
        unauthorized access attempts, and maintaining compliance audit trails.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata (id, service, title, severity).

    .OUTPUTS
        [PSCustomObject[]] Array of finding objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    foreach ($subscriptionId in $script:KeyVaultService.Keys) {
        $kvData = $script:KeyVaultService[$subscriptionId]

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

            $params = @{
                CheckMetadata  = $CheckMetadata
                Status         = $status
                StatusExtended = $message
                ResourceId     = $vault.id
                ResourceName   = $vault.name
                Location       = $vault.location
            }
            New-CIEMFinding @params
        }
    }
}
