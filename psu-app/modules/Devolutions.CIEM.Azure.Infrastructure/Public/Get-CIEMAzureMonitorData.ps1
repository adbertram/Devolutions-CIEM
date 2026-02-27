function Get-CIEMAzureMonitorData {
    <#
    .SYNOPSIS
        Fetches Azure Monitor data for all subscriptions in the current auth context.

    .DESCRIPTION
        Retrieves activity log alert rules and subscription-level diagnostic settings from
        the Azure ARM API for every subscription ID present in the current CIEM runtime
        authentication context. Returns a hashtable keyed by subscription ID, each value
        containing AlertRules and DiagnosticSettings arrays.

    .PARAMETER Api
        An optional CIEMAzureProviderApi instance passed by the CIEM scan engine. The
        parameter is accepted for pipeline compatibility but is not used internally; all
        API calls use the module-level Invoke-AzureApi helper and the provider endpoint
        configuration retrieved via Get-CIEMProvider.

    .OUTPUTS
        [hashtable]
        A hashtable keyed by subscription ID. Each entry is a nested hashtable with:
          AlertRules         - Array of activity log alert rule objects from ARM.
          DiagnosticSettings - Array of subscription-level diagnostic setting objects from ARM.

    .EXAMPLE
        $monitorData = Get-CIEMAzureMonitorData

        Returns Monitor data for all subscriptions in the authenticated context.

    .EXAMPLE
        $monitorData = Get-CIEMAzureMonitorData -Api $api

        Invoked by the CIEM scan engine with the provider API object; behaves identically
        to the parameterless call.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [CIEMAzureProviderApi]$Api
    )

    $ErrorActionPreference = 'Stop'

    $subscriptionIds = @((Get-CIEMRuntimeAuth -Provider Azure).SubscriptionIds)

    # Initialize service hashtable keyed by subscription
    $data = @{}

    if (-not $subscriptionIds -or $subscriptionIds.Count -eq 0) {
        # Nothing to process - return empty hashtable
    }
    else {
        $armApiBase = (Get-CIEMProvider -Name 'Azure').Endpoints.armApi

        foreach ($subscriptionId in $subscriptionIds) {
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

    return $data
}
