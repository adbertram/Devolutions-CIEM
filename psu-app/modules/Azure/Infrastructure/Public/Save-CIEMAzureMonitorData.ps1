function Save-CIEMAzureMonitorData {
    <#
    .SYNOPSIS
        Persists Monitor data to the azure_service_data table.
    .PARAMETER ProviderId
        The provider ID (lowercase name, e.g., 'azure').
    .PARAMETER Data
        The Monitor service data hashtable (keyed by subscription ID).
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Persists collected data to database')]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderId,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    $ErrorActionPreference = 'Stop'

    # Clear previous Monitor data
    Remove-CIEMAzureServiceData -ProviderId $ProviderId -ServiceName 'Monitor' -Confirm:$false

    foreach ($subscriptionId in $Data.Keys) {
        $sub = $Data[$subscriptionId]
        if (-not $sub) { continue }

        if ($sub.AlertRules) {
            foreach ($rule in $sub.AlertRules) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Monitor' -ResourceType 'AlertRule' `
                    -ResourceId $rule.id -ResourceName $rule.name -Data $rule
            }
        }

        if ($sub.DiagnosticSettings) {
            foreach ($ds in $sub.DiagnosticSettings) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Monitor' -ResourceType 'DiagnosticSetting' `
                    -ResourceId $ds.id -ResourceName $ds.name -Data $ds
            }
        }
    }
}
