function Initialize-StorageService {
    <#
    .SYNOPSIS
        Initializes the Storage service by pre-loading storage account configurations.

    .DESCRIPTION
        Loads Azure Storage resources from ARM API and caches them in $script:StorageService
        for use by check scripts. Resources are loaded per-subscription.

        Resources loaded:
        - Storage account configurations (encryption, network rules, access settings)
        - Blob services configuration (versioning, soft delete)
        - File services configuration (soft delete, SMB settings)
        - Blob containers and their access levels

    .PARAMETER SubscriptionIds
        Array of subscription IDs to load Storage resources from.

    .EXAMPLE
        Initialize-StorageService -SubscriptionIds @('sub-id-1')
        $script:StorageService['sub-id-1'].StorageAccounts  # Access cached accounts
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string[]]$SubscriptionIds = @()
    )

    $ErrorActionPreference = 'Stop'

    # Initialize service hashtable keyed by subscription
    $script:StorageService = @{}

    if (-not $SubscriptionIds -or $SubscriptionIds.Count -eq 0) {
        # Nothing to process - function ends naturally
    }
    else {
        $armApiBase = $script:Config.azure.endpoints.armApi

        foreach ($subscriptionId in $SubscriptionIds) {
            Write-Verbose "Loading Storage resources for subscription: $subscriptionId"

            $script:StorageService[$subscriptionId] = @{
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
                $script:StorageService[$subscriptionId].StorageAccounts = $accounts

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
                        $script:StorageService[$subscriptionId][$svc.Key][$accountName] = Invoke-AzureApi @svcParams
                    }
                }

                Write-Verbose "Storage loaded for $subscriptionId : $($accounts.Count) accounts"
            }
            else {
                Write-Verbose "No Storage Accounts found in subscription $subscriptionId"
            }
        }
    }
}
