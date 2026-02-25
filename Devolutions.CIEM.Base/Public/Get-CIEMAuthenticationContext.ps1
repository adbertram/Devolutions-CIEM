function Get-CIEMAuthenticationContext {
    <#
    .SYNOPSIS
        Returns the configured authentication context for cloud providers.

    .DESCRIPTION
        Reads authentication configuration from PSU cache and checks for the
        presence of secrets in PSU secret storage. Returns a typed context
        object for each requested provider, with the concrete type determined
        by the configured authentication method.

        By default returns contexts for all providers. Use -Provider to filter
        to a specific provider.

    .PARAMETER Provider
        Optional. Return context for specific provider(s) only.

    .OUTPUTS
        [CIEMAuthenticationContext] One typed subclass instance per provider.

    .EXAMPLE
        Get-CIEMAuthenticationContext
        # Returns contexts for all providers

    .EXAMPLE
        Get-CIEMAuthenticationContext -Provider Azure
        # Returns Azure context (e.g. CIEMAzureSPAuthenticationContext)

    .EXAMPLE
        $ctx = Get-CIEMAuthenticationContext -Provider Azure
        $ctx.GetType().Name  # CIEMAzureSPAuthenticationContext
        $ctx.TenantId        # tenant ID from config
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string[]]$Provider
    )

    $ErrorActionPreference = 'Stop'

    # Determine which providers to return
    $allProviders = Get-CIEMProvider
    $targetProviders = if ($Provider) {
        @($allProviders | Where-Object { $Provider -contains $_.Name })
    }
    else {
        @($allProviders)
    }

    foreach ($p in $targetProviders) {
        switch ($p.Name) {
            'Azure' { Get-AzureAuthenticationContextFromProvider -ProviderObj $p }
            'AWS'   { Get-AWSAuthenticationContextFromProvider -ProviderObj $p }
            default {
                # Unknown provider — return base context from provider object
                $ctx = [CIEMAuthenticationContext]::new()
                $ctx.Provider = $p.Name
                $ctx.Enabled = $p.Enabled
                $ctx.Method = $p.Authentication.Method
                $ctx
            }
        }
    }
}

function Get-AzureAuthenticationContextFromProvider {
    <#
    .SYNOPSIS
        Internal helper — builds a typed Azure auth context from provider object + secrets.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ProviderObj
    )

    $authConfig = $ProviderObj.Authentication

    # Instantiate the correct subclass based on configured method
    $ctx = switch ($authConfig.Method) {
        'ServicePrincipalSecret' {
            $c = [CIEMAzureSPAuthenticationContext]::new()
            $c.ClientId        = $authConfig.ClientId
            $c.HasClientSecret = [bool](Get-CIEMSecret 'CIEM_Azure_ClientSecret')
            $c
        }
        'ServicePrincipalCertificate' {
            $c = [CIEMAzureSPCertificateAuthenticationContext]::new()
            $c.ClientId          = $authConfig.ClientId
            $c.HasCertThumbprint = [bool](Get-CIEMSecret 'CIEM_Azure_CertThumbprint')
            $c
        }
        'ManagedIdentity' {
            $c = [CIEMAzureManagedIdentityAuthenticationContext]::new()
            $c.ManagedIdentityClientId = $authConfig.ManagedIdentityClientId
            $c
        }
        'DeviceCode' {
            [CIEMAzureDeviceCodeAuthenticationContext]::new()
        }
        'Interactive' {
            [CIEMAzureInteractiveAuthenticationContext]::new()
        }
        default {
            # Fallback for unknown method — return base Azure context
            $c = [CIEMAzureAuthenticationContext]::new()
            $c.Method = $authConfig.Method
            $c
        }
    }

    # Common Azure properties
    $ctx.Enabled  = [bool]$ProviderObj.Enabled
    $ctx.TenantId = $authConfig.TenantId

    $ctx
}

function Get-AWSAuthenticationContextFromProvider {
    <#
    .SYNOPSIS
        Internal helper — builds a typed AWS auth context from provider object + secrets.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ProviderObj
    )

    $authConfig = $ProviderObj.Authentication

    # Instantiate the correct subclass based on configured method
    $ctx = switch ($authConfig.Method) {
        'CurrentProfile' {
            $c = [CIEMAWSCurrentProfileAuthenticationContext]::new()
            $c.Profile = $authConfig.Profile
            $c
        }
        'AccessKey' {
            $c = [CIEMAWSAccessKeyAuthenticationContext]::new()
            $c.HasAccessKeyId     = [bool](Get-CIEMSecret 'CIEM_AWS_AccessKeyId')
            $c.HasSecretAccessKey = [bool](Get-CIEMSecret 'CIEM_AWS_SecretAccessKey')
            $c
        }
        default {
            # Fallback for unknown method — return base AWS context
            $c = [CIEMAWSAuthenticationContext]::new()
            $c.Method = $authConfig.Method
            $c
        }
    }

    # Common AWS properties
    $ctx.Enabled = [bool]$ProviderObj.Enabled
    $ctx.Region  = $authConfig.Region

    $ctx
}
