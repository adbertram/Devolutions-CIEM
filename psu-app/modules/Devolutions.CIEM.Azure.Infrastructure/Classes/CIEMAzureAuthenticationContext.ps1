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
