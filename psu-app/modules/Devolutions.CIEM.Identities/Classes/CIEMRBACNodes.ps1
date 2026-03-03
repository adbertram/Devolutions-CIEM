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

class CIEMAzureResourceTypeNode : CIEMGraphNode {
    [string]$ResourceTypeName     # "KeyVault", etc. (matches CIEMAzureResourceType.Name)
    [string]$DisplayName          # "Key Vault", etc.
    [string]$ArmProviderPrefix    # "Microsoft.KeyVault/vaults", etc.

    CIEMAzureResourceTypeNode() { $this.NodeType = [CIEMGraphNodeType]::AzureResourceType }
}

class CIEMAWSResourceTypeNode : CIEMGraphNode {
    [string]$ResourceTypeName     # "S3Bucket", etc. (matches CIEMAWSResourceType.Name)
    [string]$DisplayName          # "S3 Bucket", etc.
    [string]$ArnServicePrefix     # "s3", "ec2", etc.

    CIEMAWSResourceTypeNode() { $this.NodeType = [CIEMGraphNodeType]::AWSResourceType }
}
