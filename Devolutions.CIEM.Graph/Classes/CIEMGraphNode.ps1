enum CIEMGraphNodeType {
    EntraUser
    EntraGroup
    EntraServicePrincipal
    EntraApplication
    EntraAppRoleAssignment
    AzureRoleAssignment
    AzureRoleDefinition
    AzurePermissions
}

class CIEMGraphNode {
    [string]$Id
    [CIEMGraphNodeType]$NodeType

    CIEMGraphNode() {}
}
