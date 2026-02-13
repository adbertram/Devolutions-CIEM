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
        Write-CIEMLog -Severity DEBUG -Message "Loading Databricks resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            Workspaces = @()
        }

        # Load Databricks Workspaces
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Databricks/workspaces?api-version=2023-02-01"
            ResourceName = "Workspaces ($subscriptionId)"
        }
        $workspaces = Invoke-AzureApi @params

        if ($workspaces) {
            $data[$subscriptionId].Workspaces = $workspaces
        }

        # Log summary
        $workspaceCount = if ($workspaces) { $workspaces.Count } else { 0 }
        Write-CIEMLog -Severity DEBUG -Message "Databricks loaded for $subscriptionId : $workspaceCount workspaces"
    }
}

$data
