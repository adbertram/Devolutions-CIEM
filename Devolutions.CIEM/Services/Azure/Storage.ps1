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
        Write-CIEMLog -Severity DEBUG -Message "Loading Storage resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            StorageAccounts = @()
            BlobServices    = @{}
            FileServices    = @{}
            BlobContainers  = @{}
        }

        # Load Storage Accounts
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Storage/storageAccounts?api-version=2023-01-01"
            ResourceName = "StorageAccounts ($subscriptionId)"
        }
        $accounts = Invoke-AzureApi @params

        if ($accounts) {
            $data[$subscriptionId].StorageAccounts = $accounts

            foreach ($account in $accounts) {
                $accountName = $account.name
                $resourceGroup = ($account.id -split '/')[4]
                $baseUri = "$armApiBase/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$accountName"

                # Define service endpoints using data-driven pattern
                $serviceEndpoints = @{
                    BlobServices   = "$baseUri/blobServices/default?api-version=2023-01-01"
                    FileServices   = "$baseUri/fileServices/default?api-version=2023-01-01"
                    BlobContainers = "$baseUri/blobServices/default/containers?api-version=2023-01-01"
                }

                foreach ($svc in $serviceEndpoints.GetEnumerator()) {
                    $svcParams = @{
                        Uri          = $svc.Value
                        ResourceName = "$($svc.Key) ($accountName)"
                    }
                    $data[$subscriptionId][$svc.Key][$accountName] = Invoke-AzureApi @svcParams
                }
            }

            Write-CIEMLog -Severity DEBUG -Message "Storage loaded for $subscriptionId : $($accounts.Count) accounts"
        }
        else {
            Write-CIEMLog -Severity DEBUG -Message "No Storage Accounts found in subscription $subscriptionId"
        }
    }
}

$data
