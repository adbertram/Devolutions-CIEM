function Save-CIEMAzurePolicyData {
    <#
    .SYNOPSIS
        Persists Policy data to the azure_service_data table.
    .PARAMETER ProviderId
        The provider ID (lowercase name, e.g., 'azure').
    .PARAMETER Data
        The Policy service data hashtable (keyed by subscription ID).
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

    # Clear previous Policy data
    Remove-CIEMAzureServiceData -ProviderId $ProviderId -ServiceName 'Policy' -Confirm:$false

    foreach ($subscriptionId in $Data.Keys) {
        $sub = $Data[$subscriptionId]
        if (-not $sub) { continue }

        if ($sub.PolicyAssignments) {
            foreach ($key in @($sub.PolicyAssignments.Keys)) {
                $pa = $sub.PolicyAssignments[$key]
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Policy' -ResourceType 'PolicyAssignment' `
                    -ResourceId $pa.Id -ResourceName $pa.Name -Data $pa
            }
        }
    }
}
