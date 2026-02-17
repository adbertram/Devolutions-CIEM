enum CIEMCheckSeverity {
    low
    medium
    high
    critical
}

class CIEMCheckRemediation {
    [string]$Text
    [string]$Url

    CIEMCheckRemediation() {}

    CIEMCheckRemediation([string]$Text, [string]$Url) {
        $this.Text = $Text
        $this.Url = $Url
    }
}

class CIEMCheckPermissions {
    [string[]]$Graph              # Azure: Microsoft Graph API
    [string[]]$ARM                # Azure: Azure Resource Manager
    [string[]]$KeyVaultDataPlane  # Azure: Key Vault data plane
    [string[]]$IAM                # AWS: IAM actions

    CIEMCheckPermissions() {
        $this.Graph = @()
        $this.ARM = @()
        $this.KeyVaultDataPlane = @()
        $this.IAM = @()
    }
}

class CIEMCheck {
    [string]$Id
    [string]$Provider
    [string]$Service
    [string]$Title
    [string]$Description
    [string]$Risk
    [CIEMCheckSeverity]$Severity
    [CIEMCheckRemediation]$Remediation
    [string]$RelatedUrl
    [string]$CheckScript
    [string[]]$DependsOn
    [CIEMCheckPermissions]$Permissions
    [bool]$Disabled

    CIEMCheck() {}
}

# --- Authentication context classes ---

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
