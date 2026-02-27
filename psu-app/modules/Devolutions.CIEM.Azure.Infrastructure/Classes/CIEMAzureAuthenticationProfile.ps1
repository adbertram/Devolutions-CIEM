class CIEMAzureAuthenticationProfile {
    [string]$Id
    [string]$ProviderId
    [string]$Name
    [string]$Method
    [bool]$IsActive
    [string]$TenantId
    [string]$ClientId
    [string]$ManagedIdentityClientId
    [string]$SecretName
    [string]$SecretType
    [datetime]$CreatedAt
    [datetime]$UpdatedAt

    CIEMAzureAuthenticationProfile() {
        $this.IsActive = $true
        $this.CreatedAt = Get-Date
        $this.UpdatedAt = Get-Date
    }
}
