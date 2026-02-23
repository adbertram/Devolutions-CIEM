enum CIEMGraphNodeType {
    EntraUser
    EntraGroup
    EntraServicePrincipal
    EntraApplication
    EntraAppRoleAssignment
    AzureRoleAssignment
    AzureRoleDefinition
    AzurePermissions
    AzureResourceType     # Azure resource type category node (KeyVault, StorageAccount, etc.)
    AWSResourceType       # AWS resource type category node (S3Bucket, EC2Instance, etc.)
}

class CIEMGraphNode {
    [string]$Id
    [CIEMGraphNodeType]$NodeType

    CIEMGraphNode() {}
}
