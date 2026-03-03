function Get-CIEMAzureIAMData {
    <#
    .SYNOPSIS
        Retrieves IAM (Identity and Access Management) data from Azure ARM API.
    .DESCRIPTION
        Fetches role definitions, custom roles, and role assignments for all subscriptions
        in the current authentication context. Subscription IDs are derived from
        Get-CIEMAzureAuthContext.
    .PARAMETER Api
        Optional CIEMAzureProviderApi object for future API routing. Currently unused.
    .OUTPUTS
        [hashtable] - Keyed by subscription ID, each containing RoleDefinitions,
        CustomRoles, and RoleAssignments.
    .EXAMPLE
        $iamData = Get-CIEMAzureIAMData
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [CIEMAzureProviderApi]$Api
    )

    $ErrorActionPreference = 'Stop'

    # Get subscription IDs from runtime auth context
    $subscriptionIds = @((Get-CIEMAzureAuthContext).SubscriptionIds)

    # Initialize service hashtable keyed by subscription
    $data = @{}

    if (-not $subscriptionIds -or $subscriptionIds.Count -eq 0) {
        # Nothing to process - return empty hashtable
        return $data
    }

    $armApiBase = (Get-CIEMProvider -Name 'Azure').Endpoints.armApi

    foreach ($subscriptionId in $subscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading IAM resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            RoleDefinitions = $null
            CustomRoles     = $null
            RoleAssignments = $null
        }

        # Define ARM API endpoints for this subscription
        $subBase = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Authorization"
        $apiEndpoints = @{
            RoleDefinitions = "$subBase/roleDefinitions?api-version=2022-04-01"
            RoleAssignments = "$subBase/roleAssignments?api-version=2022-04-01"
        }

        foreach ($endpoint in $apiEndpoints.GetEnumerator()) {
            $params = @{
                Uri          = $endpoint.Value
                ResourceName = "$($endpoint.Key) ($subscriptionId)"
            }
            $data[$subscriptionId][$endpoint.Key] = Invoke-AzureApi @params
        }

        # Filter custom roles from role definitions
        $roleDefinitions = $data[$subscriptionId].RoleDefinitions
        if ($roleDefinitions) {
            $data[$subscriptionId].CustomRoles = $roleDefinitions | Where-Object {
                $_.properties.type -eq 'CustomRole'
            }
        }

        # Log summary
        $counts = @{
            Roles       = if ($roleDefinitions) { $roleDefinitions.Count } else { 0 }
            Custom      = if ($data[$subscriptionId].CustomRoles) { $data[$subscriptionId].CustomRoles.Count } else { 0 }
            Assignments = if ($data[$subscriptionId].RoleAssignments) { $data[$subscriptionId].RoleAssignments.Count } else { 0 }
        }

        Write-CIEMLog -Severity DEBUG -Message "IAM loaded for $subscriptionId : $($counts.Roles) roles ($($counts.Custom) custom), $($counts.Assignments) assignments"
    }

    $data
}
