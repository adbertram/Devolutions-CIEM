class CIEMAzureSecurityPrincipal {
    [string]$Id
    [string]$ProviderId
    [string]$Type
    [string]$DisplayName
    [nullable[bool]]$Enabled
    [string]$Category
    [string]$PrincipalType
    [string]$UserPrincipalName
    [string]$UserType
    [string]$AppId
    [string]$ServicePrincipalType
    [datetime]$CollectedAt

    CIEMAzureSecurityPrincipal() {
        $this.CollectedAt = Get-Date
    }
}
