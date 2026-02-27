class CIEMIdentity {
    [string]$Name              # "EntraUser", "EntraServicePrincipal", etc.
    [string]$DisplayName       # "User", "Service Principal", etc.
    [string]$Type              # "Human", "Collection", "Workload"
    [string]$Provider          # "Azure", "AWS"
    [string]$PrincipalType     # Azure RBAC principalType value ("User", "Group", "ServicePrincipal")
    [string]$GraphNodeType     # Corresponding CIEMGraphNodeType enum value
    [string]$Description

    CIEMIdentity() {}

    [string] ToString() { return $this.Name }
}
