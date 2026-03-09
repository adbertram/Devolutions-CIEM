function Save-CIEMAzureNetworkData {
    <#
    .SYNOPSIS
        Persists Network data to the azure_service_data table.
    .PARAMETER ProviderId
        The provider ID (lowercase name, e.g., 'azure').
    .PARAMETER Data
        The Network service data hashtable (keyed by subscription ID).
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Persists collected data to database')]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderId,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    $ErrorActionPreference = 'Stop'

    # Clear previous Network data
    Remove-CIEMAzureServiceData -ProviderId $ProviderId -ServiceName 'Network' -Confirm:$false

    foreach ($subscriptionId in $Data.Keys) {
        $sub = $Data[$subscriptionId]
        if (-not $sub) { continue }

        if ($sub.NetworkSecurityGroups) {
            foreach ($nsg in $sub.NetworkSecurityGroups) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Network' -ResourceType 'NetworkSecurityGroup' `
                    -ResourceId $nsg.id -ResourceName $nsg.name -Data $nsg
            }
        }

        if ($sub.PublicIpAddresses) {
            foreach ($pip in $sub.PublicIpAddresses) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Network' -ResourceType 'PublicIpAddress' `
                    -ResourceId $pip.id -ResourceName $pip.name -Data $pip
            }
        }

        if ($sub.BastionHosts) {
            foreach ($bastion in $sub.BastionHosts) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Network' -ResourceType 'BastionHost' `
                    -ResourceId $bastion.id -ResourceName $bastion.name -Data $bastion
            }
        }

        if ($sub.NetworkWatchers) {
            foreach ($watcher in $sub.NetworkWatchers) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Network' -ResourceType 'NetworkWatcher' `
                    -ResourceId $watcher.id -ResourceName $watcher.name -Data $watcher
            }
        }

        if ($sub.FlowLogs) {
            foreach ($watcherName in @($sub.FlowLogs.Keys)) {
                $flowLogs = $sub.FlowLogs[$watcherName]
                if (-not $flowLogs) { continue }
                foreach ($flowLog in $flowLogs) {
                    Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                        -ServiceName 'Network' -ResourceType 'FlowLog' `
                        -ResourceId $flowLog.id -ResourceName $flowLog.name -Data $flowLog
                }
            }
        }
    }
}
