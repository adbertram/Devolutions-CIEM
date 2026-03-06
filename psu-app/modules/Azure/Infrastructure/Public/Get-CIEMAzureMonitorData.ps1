function Get-CIEMAzureMonitorData {
    <#
    .SYNOPSIS
        Fetches Azure Monitor data for all subscriptions in the current auth context.

    .DESCRIPTION
        Retrieves activity log alert rules and subscription-level diagnostic settings from
        the Azure ARM API for every subscription ID present in the current CIEM runtime
        authentication context. Returns a hashtable keyed by subscription ID, each value
        containing AlertRules and DiagnosticSettings arrays.

    .OUTPUTS
        [hashtable]
        A hashtable keyed by subscription ID. Each entry is a nested hashtable with:
          AlertRules         - Array of activity log alert rule objects from ARM.
          DiagnosticSettings - Array of subscription-level diagnostic setting objects from ARM.

    .EXAMPLE
        $monitorData = Get-CIEMAzureMonitorData
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $ErrorActionPreference = 'Stop'

    $subscriptionIds = @($script:AzureAuthContext.SubscriptionIds)
    $data = @{}

    foreach ($subscriptionId in $subscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading Monitor resources for subscription: $subscriptionId"

        $subData = @{
            AlertRules         = @()
            DiagnosticSettings = @()
        }

        # Load Activity Log Alert Rules
        $alertRules = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Insights/activityLogAlerts?api-version=2020-10-01" -SubscriptionId $subscriptionId -ResourceName "ActivityLogAlerts"
        $alertRules = $alertRules[$subscriptionId]

        if ($alertRules) {
            $subData.AlertRules = $alertRules
        }

        # Load Subscription-Level Diagnostic Settings
        $diagSettings = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview" -SubscriptionId $subscriptionId -ResourceName "DiagnosticSettings"
        $diagSettings = $diagSettings[$subscriptionId]

        if ($diagSettings) {
            $subData.DiagnosticSettings = $diagSettings
        }

        # Log summary
        $alertCount = if ($subData.AlertRules) { $subData.AlertRules.Count } else { 0 }
        $diagCount = if ($subData.DiagnosticSettings) { $subData.DiagnosticSettings.Count } else { 0 }

        Write-CIEMLog -Severity DEBUG -Message "Monitor loaded for $subscriptionId : $alertCount alert rules, $diagCount diagnostic settings"

        $data[$subscriptionId] = $subData
    }

    $data
}
