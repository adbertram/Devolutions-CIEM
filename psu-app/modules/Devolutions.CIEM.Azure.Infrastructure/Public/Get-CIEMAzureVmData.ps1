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
        Get-CIEMRuntimeAuth instead.

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

    $subscriptionIds = @((Get-CIEMRuntimeAuth -Provider Azure).SubscriptionIds)

    # Initialize service hashtable keyed by subscription
    $data = @{}

    if (-not $subscriptionIds -or $subscriptionIds.Count -eq 0) {
        # Nothing to process - return empty hashtable
    }
    else {
        $armApiBase = (Get-CIEMProvider -Name 'Azure').Endpoints.armApi

        foreach ($subscriptionId in $subscriptionIds) {
            Write-CIEMLog -Severity DEBUG -Message "Loading VM resources for subscription: $subscriptionId"

            $data[$subscriptionId] = @{
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
                $data[$subscriptionId].VirtualMachines = $vms
            }

            # Load Disks (attached and unattached)
            $diskParams = @{
                Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Compute/disks?api-version=2023-10-02"
                ResourceName = "Disks ($subscriptionId)"
            }
            $disks = Invoke-AzureApi @diskParams

            if ($disks) {
                $data[$subscriptionId].Disks = $disks
            }

            # Load Virtual Machine Scale Sets
            $vmssParams = @{
                Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Compute/virtualMachineScaleSets?api-version=2024-03-01"
                ResourceName = "VmScaleSets ($subscriptionId)"
            }
            $scaleSets = Invoke-AzureApi @vmssParams

            if ($scaleSets) {
                $data[$subscriptionId].VmScaleSets = $scaleSets
            }

            # Load Recovery Services Vaults
            $vaultParams = @{
                Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.RecoveryServices/vaults?api-version=2023-06-01"
                ResourceName = "RecoveryVaults ($subscriptionId)"
            }
            $vaults = Invoke-AzureApi @vaultParams

            if ($vaults) {
                $data[$subscriptionId].RecoveryVaults = $vaults

                # Load Backup Protected Items per vault
                foreach ($vault in $vaults) {
                    $vaultName = $vault.name

                    $backupParams = @{
                        Uri          = "$armApiBase$($vault.id)/backupProtectedItems?api-version=2023-06-01"
                        ResourceName = "BackupItems ($vaultName)"
                    }
                    $backupItems = Invoke-AzureApi @backupParams

                    if ($backupItems) {
                        $data[$subscriptionId].BackupItems[$vaultName] = $backupItems
                    }
                }
            }

            $vmCount    = @($data[$subscriptionId].VirtualMachines).Count
            $diskCount  = @($data[$subscriptionId].Disks).Count
            $vmssCount  = @($data[$subscriptionId].VmScaleSets).Count
            $vaultCount = @($data[$subscriptionId].RecoveryVaults).Count
            Write-CIEMLog -Severity DEBUG -Message "VM loaded for $subscriptionId : $vmCount VMs, $diskCount disks, $vmssCount scale sets, $vaultCount recovery vaults"
        }
    }

    return $data
}
