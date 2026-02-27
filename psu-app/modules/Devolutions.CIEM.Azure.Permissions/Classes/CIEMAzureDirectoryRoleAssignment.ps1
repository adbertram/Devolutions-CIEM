class CIEMAzureDirectoryRoleAssignment {
    [string]$Id
    [string]$ProviderId
    [string]$PrincipalId
    [string]$RoleName
    [string]$RoleTemplateId
    [datetime]$CollectedAt

    CIEMAzureDirectoryRoleAssignment() {
        $this.CollectedAt = Get-Date
    }
}
