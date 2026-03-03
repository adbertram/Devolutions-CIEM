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

    .PARAMETER Api
        The CIEMAzureProviderApi context object. Accepted for pipeline/parameter
        consistency but not used internally; subscription IDs are derived from the
        active CIEM runtime auth context.

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
    param(
        [Parameter()]
        [CIEMAzureProviderApi]$Api
    )

    $ErrorActionPreference = 'Stop'

    Invoke-CIEMAzurePerSubscription -ServiceName 'Network' -ScriptBlock {
        param($subscriptionId, $armApiBase)

        $subData = @{
            NetworkSecurityGroups = @()
            PublicIpAddresses     = @()
            BastionHosts          = @()
            NetworkWatchers       = @()
            FlowLogs              = @{}
        }

        # Load Network Security Groups (includes security rules in response)
        $nsgParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Network/networkSecurityGroups?api-version=2023-09-01"
            ResourceName = "NetworkSecurityGroups ($subscriptionId)"
        }
        $nsgs = Invoke-AzureApi @nsgParams

        if ($nsgs) {
            $subData.NetworkSecurityGroups = $nsgs
        }

        # Load Public IP Addresses
        $pipParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Network/publicIPAddresses?api-version=2023-09-01"
            ResourceName = "PublicIpAddresses ($subscriptionId)"
        }
        $publicIps = Invoke-AzureApi @pipParams

        if ($publicIps) {
            $subData.PublicIpAddresses = $publicIps
        }

        # Load Bastion Hosts
        $bastionParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Network/bastionHosts?api-version=2023-09-01"
            ResourceName = "BastionHosts ($subscriptionId)"
        }
        $bastionHosts = Invoke-AzureApi @bastionParams

        if ($bastionHosts) {
            $subData.BastionHosts = $bastionHosts
        }

        # Load Network Watchers
        $watcherParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Network/networkWatchers?api-version=2023-09-01"
            ResourceName = "NetworkWatchers ($subscriptionId)"
        }
        $watchers = Invoke-AzureApi @watcherParams

        if ($watchers) {
            $subData.NetworkWatchers = $watchers

            # Load Flow Logs per network watcher
            foreach ($watcher in $watchers) {
                $watcherName = $watcher.name

                $flowLogParams = @{
                    Uri          = "$armApiBase$($watcher.id)/flowLogs?api-version=2023-09-01"
                    ResourceName = "FlowLogs ($watcherName)"
                }
                $flowLogs = Invoke-AzureApi @flowLogParams

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

        $subData
    }
}
