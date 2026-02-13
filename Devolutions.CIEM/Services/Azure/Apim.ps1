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
        Write-CIEMLog -Severity DEBUG -Message "Loading APIM resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            ApiManagementServices = @()
        }

        # Load API Management Services
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.ApiManagement/service?api-version=2023-05-01-preview"
            ResourceName = "ApiManagementServices ($subscriptionId)"
        }
        $services = Invoke-AzureApi @params

        if ($services) {
            $data[$subscriptionId].ApiManagementServices = $services
        }

        # Log summary
        $serviceCount = if ($services) { $services.Count } else { 0 }
        Write-CIEMLog -Severity DEBUG -Message "APIM loaded for $subscriptionId : $serviceCount API Management services"
    }
}

$data
