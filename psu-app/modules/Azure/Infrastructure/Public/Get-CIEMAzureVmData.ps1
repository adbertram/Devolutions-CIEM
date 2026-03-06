function Get-CIEMAzureVmData {
    <#
    .SYNOPSIS
        Fetches Azure VM-related data for all subscriptions in the current auth context.

    .DESCRIPTION
        Retrieves virtual machines, managed disks, virtual machine scale sets, Recovery Services
        vaults, and backup protected items from the Azure ARM API for every subscription ID
        present in the current CIEM runtime auth context. Returns a hashtable keyed by
        subscription ID, each value containing arrays of the fetched resources.

    .OUTPUTS
        [hashtable]
        A hashtable keyed by subscription ID. Each entry contains:
          VirtualMachines - array of VM resource objects
          Disks           - array of managed disk resource objects
          VmScaleSets     - array of VM scale set resource objects
          RecoveryVaults  - array of Recovery Services vault resource objects
          BackupItems     - hashtable keyed by vault name containing backup protected items

    .EXAMPLE
        $vmData = Get-CIEMAzureVmData
        $vmData['00000000-0000-0000-0000-000000000000'].VirtualMachines
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $ErrorActionPreference = 'Stop'

    $subscriptionIds = @($script:AzureAuthContext.SubscriptionIds)
    $data = @{}

    foreach ($subscriptionId in $subscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading VM resources for subscription: $subscriptionId"

        $subData = @{
            VirtualMachines = @()
            Disks           = @()
            VmScaleSets     = @()
            RecoveryVaults  = @()
            BackupItems     = @{}
        }

        # Load Virtual Machines
        $vms = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Compute/virtualMachines?api-version=2024-03-01" -SubscriptionId $subscriptionId -ResourceName "VirtualMachines"
        $vms = $vms[$subscriptionId]

        if ($vms) {
            $subData.VirtualMachines = $vms
        }

        # Load Disks (attached and unattached)
        $disks = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Compute/disks?api-version=2023-10-02" -SubscriptionId $subscriptionId -ResourceName "Disks"
        $disks = $disks[$subscriptionId]

        if ($disks) {
            $subData.Disks = $disks
        }

        # Load Virtual Machine Scale Sets
        $scaleSets = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Compute/virtualMachineScaleSets?api-version=2024-03-01" -SubscriptionId $subscriptionId -ResourceName "VmScaleSets"
        $scaleSets = $scaleSets[$subscriptionId]

        if ($scaleSets) {
            $subData.VmScaleSets = $scaleSets
        }

        # Load Recovery Services Vaults
        $vaults = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.RecoveryServices/vaults?api-version=2023-06-01" -SubscriptionId $subscriptionId -ResourceName "RecoveryVaults"
        $vaults = $vaults[$subscriptionId]

        if ($vaults) {
            $subData.RecoveryVaults = $vaults

            # Load Backup Protected Items per vault (uses full URI since path includes vault resource ID)
            foreach ($vault in $vaults) {
                $vaultName = $vault.name
                $backupItems = Invoke-AzureApi -Uri "https://management.azure.com$($vault.id)/backupProtectedItems?api-version=2023-06-01" -ResourceName "BackupItems ($vaultName)"

                if ($backupItems) {
                    $subData.BackupItems[$vaultName] = $backupItems
                }
            }
        }

        $vmCount    = @($subData.VirtualMachines).Count
        $diskCount  = @($subData.Disks).Count
        $vmssCount  = @($subData.VmScaleSets).Count
        $vaultCount = @($subData.RecoveryVaults).Count
        Write-CIEMLog -Severity DEBUG -Message "VM loaded for $subscriptionId : $vmCount VMs, $diskCount disks, $vmssCount scale sets, $vaultCount recovery vaults"

        $data[$subscriptionId] = $subData
    }

    $data
}
