function Resolve-AzureScope {
    <#
    .SYNOPSIS
        Checks if a role assignment scope contains a target scope.

    .DESCRIPTION
        Azure RBAC uses hierarchical scope containment:
        - Root scope "/" covers everything
        - Subscription scope covers all resource groups and resources within it
        - Resource group scope covers all resources within it
        - The assignment scope must be equal to or a parent of the target scope

    .PARAMETER AssignmentScope
        The scope of the role assignment, e.g., "/subscriptions/abc".

    .PARAMETER TargetScope
        The scope to check, e.g., "/subscriptions/abc/resourceGroups/rg1".

    .OUTPUTS
        [bool] True if the assignment scope contains the target scope.

    .EXAMPLE
        Resolve-AzureScope -AssignmentScope "/" -TargetScope "/subscriptions/abc"
        # Returns $true (root covers everything)

    .EXAMPLE
        Resolve-AzureScope -AssignmentScope "/subscriptions/abc" -TargetScope "/subscriptions/abc/resourceGroups/rg1"
        # Returns $true (subscription covers its resource groups)

    .EXAMPLE
        Resolve-AzureScope -AssignmentScope "/subscriptions/abc/resourceGroups/rg1" -TargetScope "/subscriptions/abc"
        # Returns $false (resource group does not cover subscription)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$AssignmentScope,

        [Parameter(Mandatory)]
        [string]$TargetScope
    )
    $ErrorActionPreference = 'Stop'

    # Normalize: lowercase, trim trailing slashes
    $assignmentNorm = $AssignmentScope.ToLowerInvariant().TrimEnd('/')
    $targetNorm = $TargetScope.ToLowerInvariant().TrimEnd('/')

    # Root scope covers everything
    if ($assignmentNorm -eq '' -or $assignmentNorm -eq '/') {
        return $true
    }

    # Exact match
    if ($assignmentNorm -eq $targetNorm) {
        return $true
    }

    # Hierarchical containment: assignment scope must be a prefix of target scope
    # followed by a "/" to ensure proper boundary (e.g., /sub/abc matches /sub/abc/rg but not /sub/abcdef)
    return $targetNorm.StartsWith("$assignmentNorm/", [System.StringComparison]::OrdinalIgnoreCase)
}
