function Get-CIEMAzureNetworkData {
    <#
    .SYNOPSIS
        Fetches Azure Network data for all subscriptions in the auth context.

    .DESCRIPTION
        Retrieves Network Security Groups (including security rules), Public IP Addresses,
        Bastion Hosts, Network Watchers, and Flow Logs from the Azure ARM API for every
        subscription ID present in the current CIEM Azure auth context.

        The result is a hashtable keyed by subscription ID. Each value is a hashtable
        with keys: NetworkSecurityGroups, PublicIpAddresses, BastionHosts,
        NetworkWatchers, and FlowLogs.

    .OUTPUTS
        [hashtable]
        A hashtable keyed by subscription ID. Each entry contains:
          - NetworkSecurityGroups : array of NSG objects
          - PublicIpAddresses     : array of public IP address objects
          - BastionHosts          : array of bastion host objects
          - NetworkWatchers       : array of network watcher objects
          - FlowLogs              : hashtable keyed by network watcher name

    .EXAMPLE
        $networkData = Get-CIEMAzureNetworkData
        $networkData['00000000-0000-0000-0000-000000000000'].NetworkSecurityGroups
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $ErrorActionPreference = 'Stop'

    $subscriptionIds = @($script:AzureAuthContext.SubscriptionIds)
    $data = @{}

    foreach ($subscriptionId in $subscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading Network resources for subscription: $subscriptionId"

        $subData = @{
            NetworkSecurityGroups = @()
            PublicIpAddresses     = @()
            BastionHosts          = @()
            NetworkWatchers       = @()
            FlowLogs              = @{}
        }

        # Load Network Security Groups (includes security rules in response)
        $nsgs = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Network/networkSecurityGroups?api-version=2023-09-01" -SubscriptionId $subscriptionId -ResourceName "NetworkSecurityGroups"
        $nsgs = $nsgs[$subscriptionId]

        if ($nsgs) {
            $subData.NetworkSecurityGroups = $nsgs
        }

        # Load Public IP Addresses
        $publicIps = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Network/publicIPAddresses?api-version=2023-09-01" -SubscriptionId $subscriptionId -ResourceName "PublicIpAddresses"
        $publicIps = $publicIps[$subscriptionId]

        if ($publicIps) {
            $subData.PublicIpAddresses = $publicIps
        }

        # Load Bastion Hosts
        $bastionHosts = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Network/bastionHosts?api-version=2023-09-01" -SubscriptionId $subscriptionId -ResourceName "BastionHosts"
        $bastionHosts = $bastionHosts[$subscriptionId]

        if ($bastionHosts) {
            $subData.BastionHosts = $bastionHosts
        }

        # Load Network Watchers
        $watchers = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Network/networkWatchers?api-version=2023-09-01" -SubscriptionId $subscriptionId -ResourceName "NetworkWatchers"
        $watchers = $watchers[$subscriptionId]

        if ($watchers) {
            $subData.NetworkWatchers = $watchers

            # Load Flow Logs per network watcher (uses full URI since path includes watcher resource ID)
            foreach ($watcher in $watchers) {
                $watcherName = $watcher.name
                $flowLogs = Invoke-AzureApi -Uri "https://management.azure.com$($watcher.id)/flowLogs?api-version=2023-09-01" -ResourceName "FlowLogs ($watcherName)"

                if ($flowLogs) {
                    $subData.FlowLogs[$watcherName] = $flowLogs
                }
            }
        }

        $nsgCount     = @($subData.NetworkSecurityGroups).Count
        $pipCount     = @($subData.PublicIpAddresses).Count
        $bastionCount = @($subData.BastionHosts).Count
        $watcherCount = @($subData.NetworkWatchers).Count
        Write-CIEMLog -Severity DEBUG -Message "Network loaded for $subscriptionId : $nsgCount NSGs, $pipCount public IPs, $bastionCount bastion hosts, $watcherCount network watchers"

        $data[$subscriptionId] = $subData
    }

    $data
}
