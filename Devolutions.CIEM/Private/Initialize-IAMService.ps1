function Initialize-IAMService {
    <#
    .SYNOPSIS
        Initializes the IAM/RBAC service by pre-loading role definitions and assignments.

    .DESCRIPTION
        Loads Azure RBAC resources from ARM API and caches them in $script:IAMService
        for use by check scripts. Resources are loaded per-subscription.

        Resources loaded:
        - Role definitions (built-in and custom)
        - Role assignments

    .PARAMETER SubscriptionIds
        Array of subscription IDs to load IAM resources from.

    .EXAMPLE
        Initialize-IAMService -SubscriptionIds @('sub-id-1', 'sub-id-2')
        $script:IAMService['sub-id-1'].RoleDefinitions  # Access cached role definitions
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string[]]$SubscriptionIds = @()
    )

    $ErrorActionPreference = 'Stop'

    # Initialize service hashtable keyed by subscription
    $script:IAMService = @{}

    if (-not $SubscriptionIds -or $SubscriptionIds.Count -eq 0) {
        # Nothing to process - function ends naturally
    }
    else {
        $armApiBase = $script:Config.azure.endpoints.armApi

        foreach ($subscriptionId in $SubscriptionIds) {
            Write-Verbose "Loading IAM resources for subscription: $subscriptionId"

            $script:IAMService[$subscriptionId] = @{
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
                $script:IAMService[$subscriptionId][$endpoint.Key] = Invoke-AzureApi @params
            }

            # Filter custom roles from role definitions
            $roleDefinitions = $script:IAMService[$subscriptionId].RoleDefinitions
            if ($roleDefinitions) {
                $script:IAMService[$subscriptionId].CustomRoles = $roleDefinitions | Where-Object {
                    $_.properties.type -eq 'CustomRole'
                }
            }

            # Log summary
            $counts = @{
                Roles       = if ($roleDefinitions) { $roleDefinitions.Count } else { 0 }
                Custom      = if ($script:IAMService[$subscriptionId].CustomRoles) { $script:IAMService[$subscriptionId].CustomRoles.Count } else { 0 }
                Assignments = if ($script:IAMService[$subscriptionId].RoleAssignments) { $script:IAMService[$subscriptionId].RoleAssignments.Count } else { 0 }
            }

            Write-Verbose "IAM loaded for $subscriptionId : $($counts.Roles) roles ($($counts.Custom) custom), $($counts.Assignments) assignments"
        }
    }
}
