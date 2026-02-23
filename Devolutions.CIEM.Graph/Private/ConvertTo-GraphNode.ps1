function ConvertTo-GraphNode {
    <#
    .SYNOPSIS
        Converts raw API data into typed CIEMGraph node objects.

    .PARAMETER RawData
        Array of raw API response objects (hashtables/PSCustomObjects).

    .PARAMETER NodeType
        The type of node to create from the raw data.

    .OUTPUTS
        [CIEMGraphNode[]] Typed node objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMGraphNode[]])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object[]]$RawData,

        [Parameter(Mandatory)]
        [CIEMGraphNodeType]$NodeType
    )
    $ErrorActionPreference = 'Stop'

    if (-not $RawData) { return @() }

    foreach ($item in $RawData) {
        switch ($NodeType) {
            'EntraUser' {
                $node = [CIEMEntraUser]::new()
                $node.Id = $item.id
                $node.UserPrincipalName = $item.userPrincipalName
                $node.DisplayName = $item.displayName
                $node.AccountEnabled = [bool]$item.accountEnabled
                $node.UserType = $item.userType
                $node.Department = $item.department
                $node.JobTitle = $item.jobTitle
                # Manager is expanded as a nested object with $select=id
                $node.ManagerId = if ($item.manager) { $item.manager.id } else { $null }
                $node
            }
            'EntraGroup' {
                $node = [CIEMEntraGroup]::new()
                $node.Id = $item.id
                $node.DisplayName = $item.displayName
                $node.SecurityEnabled = [bool]$item.securityEnabled
                $node.IsAssignableToRole = [bool]$item.isAssignableToRole
                $node.GroupTypes = @($item.groupTypes)
                $node.Visibility = $item.visibility
                $node
            }
            'EntraServicePrincipal' {
                $node = [CIEMEntraServicePrincipal]::new()
                $node.Id = $item.id
                $node.AppId = $item.appId
                $node.DisplayName = $item.displayName
                $node.ServicePrincipalType = $item.servicePrincipalType
                $node.AccountEnabled = [bool]$item.accountEnabled
                $node.SignInAudience = $item.signInAudience
                $node.Tags = @($item.tags)
                $node
            }
            'EntraApplication' {
                $node = [CIEMEntraApplication]::new()
                $node.Id = $item.id
                $node.AppId = $item.appId
                $node.DisplayName = $item.displayName
                $node.PublisherDomain = $item.publisherDomain
                $node.SignInAudience = $item.signInAudience
                $node
            }
            'EntraAppRoleAssignment' {
                $node = [CIEMEntraAppRoleAssignment]::new()
                $node.Id = $item.id
                $node.AppRoleId = $item.appRoleId
                $node.PrincipalId = $item.principalId
                $node.PrincipalType = $item.principalType
                $node.PrincipalDisplayName = $item.principalDisplayName
                $node.ResourceId = $item.resourceId
                $node.ResourceDisplayName = $item.resourceDisplayName
                $node.CreatedDateTime = $item.createdDateTime
                $node
            }
            'AzureRoleAssignment' {
                $node = [CIEMAzureRoleAssignment]::new()
                $node.Id = $item.id
                $props = $item.properties
                $node.PrincipalId = $props.principalId
                $node.PrincipalType = $props.principalType
                $node.RoleDefinitionId = $props.roleDefinitionId
                $node.Scope = $props.scope
                $node.ScopeType = if ($props.scope -match '^/subscriptions/[^/]+$') {
                    'Subscription'
                } elseif ($props.scope -match '/resourceGroups/[^/]+$') {
                    'ResourceGroup'
                } elseif ($props.scope -eq '/') {
                    'Root'
                } else {
                    'Resource'
                }
                $node.Condition = $props.condition
                $node.CreatedBy = $props.createdBy
                $node.UpdatedBy = $props.updatedBy
                $node
            }
            'AzureRoleDefinition' {
                $node = [CIEMAzureRoleDefinition]::new()
                $node.Id = $item.id
                $props = $item.properties
                $node.RoleName = $props.roleName
                $node.Description = $props.description
                $node.AssignableScopes = @($props.assignableScopes)
                $node.RoleType = $props.type
                $node
            }
            'AzurePermissions' {
                # Each permission set from a role definition gets its own node
                $node = [CIEMAzurePermissions]::new()
                $node.Id = $item._permissionId  # Synthetic ID set by caller
                $node.Actions = @($item.actions)
                $node.NotActions = @($item.notActions)
                $node.DataActions = @($item.dataActions)
                $node.NotDataActions = @($item.notDataActions)
                $node
            }
        }
    }
}
