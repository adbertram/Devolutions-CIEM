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
        Write-CIEMLog -Severity DEBUG -Message "Loading AKS resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            ManagedClusters = @()
        }

        # Load Managed Clusters
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.ContainerService/managedClusters?api-version=2024-01-01"
            ResourceName = "ManagedClusters ($subscriptionId)"
        }
        $clusters = Invoke-AzureApi @params

        if ($clusters) {
            $data[$subscriptionId].ManagedClusters = $clusters
        }

        # Log summary
        $clusterCount = if ($clusters) { $clusters.Count } else { 0 }
        Write-CIEMLog -Severity DEBUG -Message "AKS loaded for $subscriptionId : $clusterCount managed clusters"
    }
}

$data
