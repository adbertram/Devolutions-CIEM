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
        Write-CIEMLog -Severity DEBUG -Message "Loading Application Insights resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            Components = @()
        }

        # Load Application Insights components
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Insights/components?api-version=2020-02-02"
            ResourceName = "Application Insights Components ($subscriptionId)"
        }
        $components = Invoke-AzureApi @params

        if ($components) {
            $data[$subscriptionId].Components = $components
        }

        # Log summary
        $componentCount = if ($components) { $components.Count } else { 0 }
        Write-CIEMLog -Severity DEBUG -Message "Application Insights loaded for $subscriptionId : $componentCount components"
    }
}

$data
