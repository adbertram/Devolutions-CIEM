function Get-CIEMAzureVmData {
    <#
    .SYNOPSIS
        Fetches Azure VM-related data for all subscriptions in the current auth context.

    .DESCRIPTION
        Retrieves virtual machines, managed disks, virtual machine scale sets, Recovery Services
        vaults, and backup protected items from the Azure ARM API for every subscription ID
        present in the current CIEM runtime auth context. Returns a hashtable keyed by
        subscription ID, each value containing arrays of the fetched resources.

    .PARAMETER Api
        The CIEMAzureProviderApi instance for the current provider session. Accepted for
        pipeline compatibility but not used internally; subscription IDs are derived from
        Get-CIEMAzureAuthContext instead.

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
    param(
        [Parameter()]
        [CIEMAzureProviderApi]$Api
    )

    $ErrorActionPreference = 'Stop'

    Invoke-CIEMAzurePerSubscription -ServiceName 'VM' -ScriptBlock {
        param($subscriptionId, $armApiBase)

        $subData = @{
            VirtualMachines = @()
            Disks           = @()
            VmScaleSets     = @()
            RecoveryVaults  = @()
            BackupItems     = @{}
        }

        # Load Virtual Machines
        $vmParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Compute/virtualMachines?api-version=2024-03-01"
            ResourceName = "VirtualMachines ($subscriptionId)"
        }
        $vms = Invoke-AzureApi @vmParams

        if ($vms) {
            $subData.VirtualMachines = $vms
        }

        # Load Disks (attached and unattached)
        $diskParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Compute/disks?api-version=2023-10-02"
            ResourceName = "Disks ($subscriptionId)"
        }
        $disks = Invoke-AzureApi @diskParams

        if ($disks) {
            $subData.Disks = $disks
        }

        # Load Virtual Machine Scale Sets
        $vmssParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Compute/virtualMachineScaleSets?api-version=2024-03-01"
            ResourceName = "VmScaleSets ($subscriptionId)"
        }
        $scaleSets = Invoke-AzureApi @vmssParams

        if ($scaleSets) {
            $subData.VmScaleSets = $scaleSets
        }

        # Load Recovery Services Vaults
        $vaultParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.RecoveryServices/vaults?api-version=2023-06-01"
            ResourceName = "RecoveryVaults ($subscriptionId)"
        }
        $vaults = Invoke-AzureApi @vaultParams

        if ($vaults) {
            $subData.RecoveryVaults = $vaults

            # Load Backup Protected Items per vault
            foreach ($vault in $vaults) {
                $vaultName = $vault.name

                $backupParams = @{
                    Uri          = "$armApiBase$($vault.id)/backupProtectedItems?api-version=2023-06-01"
                    ResourceName = "BackupItems ($vaultName)"
                }
                $backupItems = Invoke-AzureApi @backupParams

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

        $subData
    }
}
