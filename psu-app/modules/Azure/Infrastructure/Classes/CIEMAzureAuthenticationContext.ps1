# Single flat Azure authentication context class.
# Replaces the previous 6-class hierarchy (CIEMAzureAuthenticationContext,
# CIEMAzureSPAuthenticationContext, etc.). PSU runspaces strip class type
# info on serialization, so a single class with nullable properties works
# better than inheritance. The Method string tells which fields are relevant.

class CIEMAzureAuthContext {
    [string]$ProfileId              # FK to azure_authentication_profiles.id
    [string]$ProfileName            # Human-readable profile name
    [string]$ProviderId             # FK to providers.id
    [string]$Method                 # 'ServicePrincipalSecret' | 'ServicePrincipalCertificate' | 'ManagedIdentity'
    [string]$TenantId
    [string]$ClientId               # SP methods only
    [string]$ManagedIdentityClientId # MI only (null = system-assigned)
    [string]$AccountId              # Authenticated principal ID
    [string]$AccountType            # 'ServicePrincipal' | 'ManagedIdentity'
    [string[]]$SubscriptionIds
    [string]$ARMToken
    [string]$GraphToken
    [string]$KeyVaultToken
    [datetime]$TokenExpiresAt       # Earliest expiry among tokens
    [datetime]$ConnectedAt
    [string]$LastError
    [bool]$IsConnected

    CIEMAzureAuthContext() {
        $this.IsConnected = $false
        $this.SubscriptionIds = @()
    }
}
