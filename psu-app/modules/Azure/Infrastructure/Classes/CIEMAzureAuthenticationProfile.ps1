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

    # Resolved secrets (transient - NOT persisted to PSU Cache)
    [string]$ClientSecret
    [string]$CertificatePfxBase64
    [string]$CertificatePassword
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate

    CIEMAzureAuthenticationProfile() {
        $this.IsActive = $true
        $this.CreatedAt = Get-Date
        $this.UpdatedAt = Get-Date
    }
}
