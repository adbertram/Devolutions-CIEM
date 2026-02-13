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
    $apiVersion = '2023-06-30'

    foreach ($subscriptionId in $SubscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading MySQL resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            FlexibleServers = @()
            Configurations  = @{}
        }

        # Load Flexible Servers
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.DBforMySQL/flexibleServers?api-version=$apiVersion"
            ResourceName = "MySQL FlexibleServers ($subscriptionId)"
        }
        $servers = Invoke-AzureApi @params

        if ($servers) {
            $data[$subscriptionId].FlexibleServers = $servers

            foreach ($server in $servers) {
                $serverName = $server.name
                $serverId = $server.id

                # Load configurations per server
                $configParams = @{
                    Uri          = "$armApiBase$serverId/configurations?api-version=$apiVersion"
                    ResourceName = "Configurations ($serverName)"
                }
                $data[$subscriptionId].Configurations[$serverName] = Invoke-AzureApi @configParams
            }

            Write-CIEMLog -Severity DEBUG -Message "MySQL loaded for $subscriptionId : $($servers.Count) flexible servers"
        }
        else {
            Write-CIEMLog -Severity DEBUG -Message "No MySQL Flexible Servers found in subscription $subscriptionId"
        }
    }
}

$data
