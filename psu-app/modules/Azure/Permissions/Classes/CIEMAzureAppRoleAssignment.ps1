class CIEMAzureAppRoleAssignment {
    [string]$Id
    [string]$ProviderId
    [string]$PrincipalId
    [string]$PrincipalType
    [string]$ResourceId
    [string]$ResourceDisplayName
    [string]$AppRoleId
    [string]$AppRoleValue
    [datetime]$CollectedAt

    CIEMAzureAppRoleAssignment() {
        $this.CollectedAt = Get-Date
    }
}
