class CIEMAzureRoleAssignment : CIEMGraphNode {
    [string]$PrincipalId
    [string]$PrincipalType
    [string]$RoleDefinitionId
    [string]$Scope
    [string]$ScopeType
    [string]$Condition
    [string]$CreatedBy
    [string]$UpdatedBy

    CIEMAzureRoleAssignment() { $this.NodeType = [CIEMGraphNodeType]::AzureRoleAssignment }
}

class CIEMAzureRoleDefinition : CIEMGraphNode {
    [string]$RoleName
    [string]$Description
    [string[]]$AssignableScopes
    [string]$RoleType

    CIEMAzureRoleDefinition() { $this.NodeType = [CIEMGraphNodeType]::AzureRoleDefinition }
}

class CIEMAzurePermissions : CIEMGraphNode {
    [string[]]$Actions
    [string[]]$NotActions
    [string[]]$DataActions
    [string[]]$NotDataActions

    CIEMAzurePermissions() { $this.NodeType = [CIEMGraphNodeType]::AzurePermissions }
}
