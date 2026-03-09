function Save-CIEMAzureVmData {
    <#
    .SYNOPSIS
        Persists VM data to the azure_service_data table.
    .PARAMETER ProviderId
        The provider ID (lowercase name, e.g., 'azure').
    .PARAMETER Data
        The VM service data hashtable (keyed by subscription ID).
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

    # Clear previous Vm data
    Remove-CIEMAzureServiceData -ProviderId $ProviderId -ServiceName 'Vm' -Confirm:$false

    foreach ($subscriptionId in $Data.Keys) {
        $sub = $Data[$subscriptionId]
        if (-not $sub) { continue }

        if ($sub.VirtualMachines) {
            foreach ($vm in $sub.VirtualMachines) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Vm' -ResourceType 'VirtualMachine' `
                    -ResourceId $vm.id -ResourceName $vm.name -Data $vm
            }
        }

        if ($sub.Disks) {
            foreach ($disk in $sub.Disks) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Vm' -ResourceType 'Disk' `
                    -ResourceId $disk.id -ResourceName $disk.name -Data $disk
            }
        }

        if ($sub.VmScaleSets) {
            foreach ($vmss in $sub.VmScaleSets) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Vm' -ResourceType 'VmScaleSet' `
                    -ResourceId $vmss.id -ResourceName $vmss.name -Data $vmss
            }
        }

        if ($sub.RecoveryVaults) {
            foreach ($vault in $sub.RecoveryVaults) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Vm' -ResourceType 'RecoveryVault' `
                    -ResourceId $vault.id -ResourceName $vault.name -Data $vault
            }
        }

        if ($sub.BackupItems) {
            foreach ($vaultName in @($sub.BackupItems.Keys)) {
                $backupItems = $sub.BackupItems[$vaultName]
                if (-not $backupItems) { continue }
                foreach ($item in $backupItems) {
                    Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                        -ServiceName 'Vm' -ResourceType 'BackupItem' `
                        -ResourceId $item.id -ResourceName $item.name -Data $item
                }
            }
        }
    }
}
