function Save-CIEMAzureIAMData {
    <#
    .SYNOPSIS
        Persists IAM data to the azure_service_data table.
    .DESCRIPTION
        Clears previous IAM data for the provider, then saves role definitions,
        custom roles, and role assignments as JSON blobs in azure_service_data,
        keyed by subscription ID.
    .PARAMETER ProviderId
        The provider ID (lowercase name, e.g., 'azure').
    .PARAMETER Data
        The IAM service data hashtable from Get-CIEMAzureIAMData (keyed by subscription ID).
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

    # Clear previous IAM data
    Remove-CIEMAzureServiceData -ProviderId $ProviderId -ServiceName 'IAM' -Confirm:$false

    foreach ($subscriptionId in $Data.Keys) {
        $subData = $Data[$subscriptionId]
        if (-not $subData) { continue }

        if ($subData.RoleDefinitions) {
            foreach ($rd in $subData.RoleDefinitions) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'IAM' -ResourceType 'RoleDefinition' `
                    -ResourceId $rd.id -ResourceName ($rd.properties.roleName ?? $rd.id) -Data $rd
            }
        }

        if ($subData.CustomRoles) {
            foreach ($cr in $subData.CustomRoles) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'IAM' -ResourceType 'CustomRole' `
                    -ResourceId $cr.id -ResourceName ($cr.properties.roleName ?? $cr.id) -Data $cr
            }
        }

        if ($subData.RoleAssignments) {
            foreach ($ra in $subData.RoleAssignments) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'IAM' -ResourceType 'RoleAssignment' `
                    -ResourceId $ra.id -ResourceName ($ra.properties.description ?? $ra.id) -Data $ra
            }
        }
    }
}
