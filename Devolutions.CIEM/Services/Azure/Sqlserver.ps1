[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$SubscriptionIds = @()
)

$ErrorActionPreference = 'Stop'

# Initialize service hashtable keyed by subscription
$data = @{}

if (-not $SubscriptionIds -or $SubscriptionIds.Count -eq 0) {
    # Nothing to process - script ends naturally
}
else {
    $armApiBase = (Get-CIEMProvider -Name 'Azure').Endpoints.armApi
    $apiVersion = '2023-05-01-preview'

    foreach ($subscriptionId in $SubscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading SQL Server resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            Servers              = @()
            AuditingSettings     = @{}
            SecurityAlertPolicies = @{}
            Administrators       = @{}
            VulnerabilityAssessments = @{}
            FirewallRules        = @{}
            EncryptionProtectors = @{}
            Databases            = @{}
            TransparentDataEncryption = @{}
        }

        # Load SQL Servers
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Sql/servers?api-version=$apiVersion"
            ResourceName = "SqlServers ($subscriptionId)"
        }
        $servers = Invoke-AzureApi @params

        if ($servers) {
            $data[$subscriptionId].Servers = $servers

            foreach ($server in $servers) {
                $serverName = $server.name
                $serverId = $server.id

                # Load server-level sub-resources using data-driven pattern
                $serverEndpoints = @{
                    AuditingSettings         = "$armApiBase$serverId/auditingSettings/default?api-version=$apiVersion"
                    SecurityAlertPolicies    = "$armApiBase$serverId/securityAlertPolicies/Default?api-version=$apiVersion"
                    VulnerabilityAssessments = "$armApiBase$serverId/vulnerabilityAssessments/default?api-version=$apiVersion"
                    EncryptionProtectors     = "$armApiBase$serverId/encryptionProtectors/current?api-version=$apiVersion"
                }

                foreach ($ep in $serverEndpoints.GetEnumerator()) {
                    $epParams = @{
                        Uri          = $ep.Value
                        ResourceName = "$($ep.Key) ($serverName)"
                    }
                    $data[$subscriptionId][$ep.Key][$serverName] = Invoke-AzureApi @epParams
                }

                # Load collection sub-resources (return arrays)
                $collectionEndpoints = @{
                    Administrators  = "$armApiBase$serverId/administrators?api-version=$apiVersion"
                    FirewallRules   = "$armApiBase$serverId/firewallRules?api-version=$apiVersion"
                }

                foreach ($ce in $collectionEndpoints.GetEnumerator()) {
                    $ceParams = @{
                        Uri          = $ce.Value
                        ResourceName = "$($ce.Key) ($serverName)"
                    }
                    $data[$subscriptionId][$ce.Key][$serverName] = Invoke-AzureApi @ceParams
                }

                # Load Databases
                $dbParams = @{
                    Uri          = "$armApiBase$serverId/databases?api-version=$apiVersion"
                    ResourceName = "Databases ($serverName)"
                }
                $databases = Invoke-AzureApi @dbParams

                if ($databases) {
                    $data[$subscriptionId].Databases[$serverName] = $databases

                    # Load TDE for each database
                    $data[$subscriptionId].TransparentDataEncryption[$serverName] = @{}
                    foreach ($db in $databases) {
                        $dbName = $db.name
                        $tdeParams = @{
                            Uri          = "$armApiBase$($db.id)/transparentDataEncryption?api-version=$apiVersion"
                            ResourceName = "TDE ($serverName/$dbName)"
                        }
                        $data[$subscriptionId].TransparentDataEncryption[$serverName][$dbName] = Invoke-AzureApi @tdeParams
                    }
                }
            }

            Write-CIEMLog -Severity DEBUG -Message "SQL Server loaded for $subscriptionId : $($servers.Count) servers"
        }
        else {
            Write-CIEMLog -Severity DEBUG -Message "No SQL Servers found in subscription $subscriptionId"
        }
    }
}

$data
