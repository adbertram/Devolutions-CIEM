# Authentication context classes — extracted from CIEMCheck.ps1 into Base module

# Base class for all authentication contexts
class CIEMAuthenticationContext {
    [string]$Provider
    [bool]$Enabled
    [string]$Method
}

# --- Azure contexts ---

class CIEMAzureAuthenticationContext : CIEMAuthenticationContext {
    [string]$TenantId

    CIEMAzureAuthenticationContext() {
        $this.Provider = 'Azure'
    }
}

class CIEMAzureSPAuthenticationContext : CIEMAzureAuthenticationContext {
    [string]$ClientId
    [bool]$HasClientSecret  # true when secret exists in PSU secret store

    CIEMAzureSPAuthenticationContext() {
        $this.Method = 'ServicePrincipalSecret'
    }
}

class CIEMAzureSPCertificateAuthenticationContext : CIEMAzureAuthenticationContext {
    [string]$ClientId
    [bool]$HasCertThumbprint  # true when thumbprint exists in PSU secret store

    CIEMAzureSPCertificateAuthenticationContext() {
        $this.Method = 'ServicePrincipalCertificate'
    }
}

class CIEMAzureManagedIdentityAuthenticationContext : CIEMAzureAuthenticationContext {
    [string]$ManagedIdentityClientId  # null = system-assigned

    CIEMAzureManagedIdentityAuthenticationContext() {
        $this.Method = 'ManagedIdentity'
    }
}

class CIEMAzureDeviceCodeAuthenticationContext : CIEMAzureAuthenticationContext {
    CIEMAzureDeviceCodeAuthenticationContext() {
        $this.Method = 'DeviceCode'
    }
}

class CIEMAzureInteractiveAuthenticationContext : CIEMAzureAuthenticationContext {
    CIEMAzureInteractiveAuthenticationContext() {
        $this.Method = 'Interactive'
    }
}

# --- AWS contexts ---

class CIEMAWSAuthenticationContext : CIEMAuthenticationContext {
    [string]$Region

    CIEMAWSAuthenticationContext() {
        $this.Provider = 'AWS'
    }
}

class CIEMAWSCurrentProfileAuthenticationContext : CIEMAWSAuthenticationContext {
    [string]$Profile

    CIEMAWSCurrentProfileAuthenticationContext() {
        $this.Method = 'CurrentProfile'
    }
}

class CIEMAWSAccessKeyAuthenticationContext : CIEMAWSAuthenticationContext {
    [bool]$HasAccessKeyId      # true when key exists in PSU secret store
    [bool]$HasSecretAccessKey  # true when key exists in PSU secret store

    CIEMAWSAccessKeyAuthenticationContext() {
        $this.Method = 'AccessKey'
    }
}
