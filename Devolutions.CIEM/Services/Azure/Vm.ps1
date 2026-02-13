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

    foreach ($subscriptionId in $SubscriptionIds) {
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

        $vmCount = @($data[$subscriptionId].VirtualMachines).Count
        $diskCount = @($data[$subscriptionId].Disks).Count
        $vmssCount = @($data[$subscriptionId].VmScaleSets).Count
        $vaultCount = @($data[$subscriptionId].RecoveryVaults).Count
        Write-CIEMLog -Severity DEBUG -Message "VM loaded for $subscriptionId : $vmCount VMs, $diskCount disks, $vmssCount scale sets, $vaultCount recovery vaults"
    }
}

$data
