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
        Write-CIEMLog -Severity DEBUG -Message "Loading AI Search resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            SearchServices = @()
        }

        # Load Search Services
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Search/searchServices?api-version=2023-11-01"
            ResourceName = "SearchServices ($subscriptionId)"
        }
        $services = Invoke-AzureApi @params

        if ($services) {
            $data[$subscriptionId].SearchServices = $services
        }

        # Log summary
        $serviceCount = if ($services) { $services.Count } else { 0 }
        Write-CIEMLog -Severity DEBUG -Message "AI Search loaded for $subscriptionId : $serviceCount search services"
    }
}

$data
