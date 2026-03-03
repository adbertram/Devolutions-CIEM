class CIEMAzureRoleDefinition {
    [string]$Id
    [string]$ProviderId
    [string]$RoleName
    [string]$RoleType
    [string]$Description
    [string]$AssignableScopes
    [datetime]$CollectedAt

    CIEMAzureRoleDefinition() {
        $this.CollectedAt = Get-Date
    }
}
