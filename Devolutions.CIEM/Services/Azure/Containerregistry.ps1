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
        Write-CIEMLog -Severity DEBUG -Message "Loading Container Registry resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            Registries = @()
        }

        # Load Container Registries
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.ContainerRegistry/registries?api-version=2023-07-01"
            ResourceName = "Registries ($subscriptionId)"
        }
        $registries = Invoke-AzureApi @params

        if ($registries) {
            $data[$subscriptionId].Registries = $registries
        }

        # Log summary
        $registryCount = if ($registries) { $registries.Count } else { 0 }
        Write-CIEMLog -Severity DEBUG -Message "Container Registry loaded for $subscriptionId : $registryCount registries"
    }
}

$data
