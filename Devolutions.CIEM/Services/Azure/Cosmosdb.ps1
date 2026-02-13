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
        Write-CIEMLog -Severity DEBUG -Message "Loading CosmosDB resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            DatabaseAccounts = @()
        }

        # Load Database Accounts
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.DocumentDB/databaseAccounts?api-version=2024-02-15-preview"
            ResourceName = "DatabaseAccounts ($subscriptionId)"
        }
        $accounts = Invoke-AzureApi @params

        if ($accounts) {
            $data[$subscriptionId].DatabaseAccounts = $accounts
        }

        # Log summary
        $accountCount = if ($accounts) { $accounts.Count } else { 0 }
        Write-CIEMLog -Severity DEBUG -Message "CosmosDB loaded for $subscriptionId : $accountCount database accounts"
    }
}

$data
