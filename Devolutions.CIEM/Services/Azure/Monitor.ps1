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
        Write-CIEMLog -Severity DEBUG -Message "Loading Monitor resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            AlertRules         = @()
            DiagnosticSettings = @()
        }

        # Load Activity Log Alert Rules
        $alertParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Insights/activityLogAlerts?api-version=2020-10-01"
            ResourceName = "ActivityLogAlerts ($subscriptionId)"
        }
        $alertRules = Invoke-AzureApi @alertParams

        if ($alertRules) {
            $data[$subscriptionId].AlertRules = $alertRules
        }

        # Load Subscription-Level Diagnostic Settings
        $diagParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
            ResourceName = "DiagnosticSettings ($subscriptionId)"
        }
        $diagSettings = Invoke-AzureApi @diagParams

        if ($diagSettings) {
            $data[$subscriptionId].DiagnosticSettings = $diagSettings
        }

        # Log summary
        $alertCount = if ($data[$subscriptionId].AlertRules) { $data[$subscriptionId].AlertRules.Count } else { 0 }
        $diagCount = if ($data[$subscriptionId].DiagnosticSettings) { $data[$subscriptionId].DiagnosticSettings.Count } else { 0 }

        Write-CIEMLog -Severity DEBUG -Message "Monitor loaded for $subscriptionId : $alertCount alert rules, $diagCount diagnostic settings"
    }
}

$data
