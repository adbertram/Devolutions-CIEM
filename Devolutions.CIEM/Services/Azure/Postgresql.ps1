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
    $apiVersion = '2023-06-01-preview'

    foreach ($subscriptionId in $SubscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading PostgreSQL resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            FlexibleServers = @()
            Configurations  = @{}
            FirewallRules   = @{}
            Administrators  = @{}
        }

        # Load Flexible Servers
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.DBforPostgreSQL/flexibleServers?api-version=$apiVersion"
            ResourceName = "PostgreSQL FlexibleServers ($subscriptionId)"
        }
        $servers = Invoke-AzureApi @params

        if ($servers) {
            $data[$subscriptionId].FlexibleServers = $servers

            foreach ($server in $servers) {
                $serverName = $server.name
                $serverId = $server.id

                # Load sub-resources per server
                $serverEndpoints = @{
                    Configurations = "$armApiBase$serverId/configurations?api-version=$apiVersion"
                    FirewallRules  = "$armApiBase$serverId/firewallRules?api-version=$apiVersion"
                    Administrators = "$armApiBase$serverId/administrators?api-version=$apiVersion"
                }

                foreach ($ep in $serverEndpoints.GetEnumerator()) {
                    $epParams = @{
                        Uri          = $ep.Value
                        ResourceName = "$($ep.Key) ($serverName)"
                    }
                    $data[$subscriptionId][$ep.Key][$serverName] = Invoke-AzureApi @epParams
                }
            }

            Write-CIEMLog -Severity DEBUG -Message "PostgreSQL loaded for $subscriptionId : $($servers.Count) flexible servers"
        }
        else {
            Write-CIEMLog -Severity DEBUG -Message "No PostgreSQL Flexible Servers found in subscription $subscriptionId"
        }
    }
}

$data
