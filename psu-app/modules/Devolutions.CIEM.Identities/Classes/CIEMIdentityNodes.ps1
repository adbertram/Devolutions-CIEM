class CIEMEntraUser : CIEMGraphNode {
    [string]$UserPrincipalName
    [string]$DisplayName
    [bool]$AccountEnabled
    [string]$UserType
    [string]$ManagerId
    [string]$Department
    [string]$JobTitle

    CIEMEntraUser() { $this.NodeType = [CIEMGraphNodeType]::EntraUser }
}

class CIEMEntraGroup : CIEMGraphNode {
    [string]$DisplayName
    [bool]$SecurityEnabled
    [bool]$IsAssignableToRole
    [string[]]$GroupTypes
    [string]$Visibility

    CIEMEntraGroup() { $this.NodeType = [CIEMGraphNodeType]::EntraGroup }
}

class CIEMEntraServicePrincipal : CIEMGraphNode {
    [string]$AppId
    [string]$DisplayName
    [string]$ServicePrincipalType
    [bool]$AccountEnabled
    [string]$SignInAudience
    [string[]]$Tags

    CIEMEntraServicePrincipal() { $this.NodeType = [CIEMGraphNodeType]::EntraServicePrincipal }
}

class CIEMEntraApplication : CIEMGraphNode {
    [string]$AppId
    [string]$DisplayName
    [string]$PublisherDomain
    [string]$SignInAudience

    CIEMEntraApplication() { $this.NodeType = [CIEMGraphNodeType]::EntraApplication }
}

class CIEMEntraAppRoleAssignment : CIEMGraphNode {
    [string]$AppRoleId
    [string]$PrincipalId
    [string]$PrincipalType
    [string]$PrincipalDisplayName
    [string]$ResourceId
    [string]$ResourceDisplayName
    [string]$CreatedDateTime

    CIEMEntraAppRoleAssignment() { $this.NodeType = [CIEMGraphNodeType]::EntraAppRoleAssignment }
}
