function ConvertTo-CIEMProvider {
    <#
    .SYNOPSIS
        Converts a PSCustomObject to a typed CIEMProvider instance.

    .DESCRIPTION
        Reconstructs a CIEMProvider class instance from a PSCustomObject,
        including the correct typed authentication context subclass.
        Handles objects deserialized from PSU cache where class type
        information is lost.

    .PARAMETER InputObject
        The PSCustomObject (or CIEMProvider) to convert.

    .OUTPUTS
        [CIEMProvider]
    #>
    [CmdletBinding()]
    [OutputType([CIEMProvider])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($InputObject -is [CIEMProvider]) {
            return $InputObject
        }

        $provider = [CIEMProvider]::new()
        $provider.Name = $InputObject.Name
        $provider.Enabled = [bool]$InputObject.Enabled
        $provider.IsDefault = [bool]$InputObject.IsDefault
        $provider.Endpoints = $InputObject.Endpoints
        $provider.ResourceFilter = @($InputObject.ResourceFilter)

        # Reconstruct the typed authentication context
        $authRaw = $InputObject.Authentication
        $authProvider = if ($authRaw.Provider) { $authRaw.Provider } else { $InputObject.Name }
        $authMethod = if ($authRaw.Method) { $authRaw.Method } else { '' }

        switch ($authProvider) {
            'Azure' {
                switch ($authMethod) {
                    'ServicePrincipalSecret' {
                        $auth = [CIEMAzureSPAuthenticationContext]::new()
                        $auth.ClientId = $authRaw.ClientId
                        $auth.HasClientSecret = if ($authRaw.PSObject.Properties['HasClientSecret']) { [bool]$authRaw.HasClientSecret } else { $false }
                    }
                    'ServicePrincipalCertificate' {
                        $auth = [CIEMAzureSPCertificateAuthenticationContext]::new()
                        $auth.ClientId = $authRaw.ClientId
                        $auth.HasCertThumbprint = if ($authRaw.PSObject.Properties['HasCertThumbprint']) { [bool]$authRaw.HasCertThumbprint } else { $false }
                    }
                    'ManagedIdentity' {
                        $auth = [CIEMAzureManagedIdentityAuthenticationContext]::new()
                        $auth.ManagedIdentityClientId = $authRaw.ManagedIdentityClientId
                    }
                    'DeviceCode' {
                        $auth = [CIEMAzureDeviceCodeAuthenticationContext]::new()
                    }
                    'Interactive' {
                        $auth = [CIEMAzureInteractiveAuthenticationContext]::new()
                    }
                    default {
                        $auth = [CIEMAzureAuthenticationContext]::new()
                    }
                }
                $auth.TenantId = $authRaw.TenantId
            }
            'AWS' {
                switch ($authMethod) {
                    'CurrentProfile' {
                        $auth = [CIEMAWSCurrentProfileAuthenticationContext]::new()
                        $auth.Profile = $authRaw.Profile
                    }
                    'AccessKey' {
                        $auth = [CIEMAWSAccessKeyAuthenticationContext]::new()
                        $auth.HasAccessKeyId = if ($authRaw.PSObject.Properties['HasAccessKeyId']) { [bool]$authRaw.HasAccessKeyId } else { $false }
                        $auth.HasSecretAccessKey = if ($authRaw.PSObject.Properties['HasSecretAccessKey']) { [bool]$authRaw.HasSecretAccessKey } else { $false }
                    }
                    default {
                        $auth = [CIEMAWSAuthenticationContext]::new()
                    }
                }
                $auth.Region = $authRaw.Region
            }
            default {
                $auth = [CIEMAuthenticationContext]::new()
                $auth.Provider = $authProvider
                $auth.Method = $authMethod
            }
        }
        $auth.Enabled = [bool]$authRaw.Enabled
        $provider.Authentication = $auth

        $provider
    }
}
