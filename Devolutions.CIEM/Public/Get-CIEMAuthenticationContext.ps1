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
        [ValidateSet('Azure', 'AWS')]
        [string[]]$Provider
    )

    $ErrorActionPreference = 'Stop'

    # Ensure config is loaded
    if (-not $script:Config) {
        $script:Config = Get-CIEMConfig
    }

    # Determine which providers to return
    $targetProviders = if ($Provider) { @($Provider) } else { @('Azure', 'AWS') }

    foreach ($p in $targetProviders) {
        switch ($p) {
            'Azure' { Get-AzureAuthenticationContextFromConfig }
            'AWS'   { Get-AWSAuthenticationContextFromConfig }
        }
    }
}

function Get-AzureAuthenticationContextFromConfig {
    <#
    .SYNOPSIS
        Internal helper — builds a typed Azure auth context from config + secrets.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $authConfig = $script:Config.azure.authentication

    # Instantiate the correct subclass based on configured method
    $ctx = switch ($authConfig.method) {
        'ServicePrincipalSecret' {
            $c = [CIEMAzureSPAuthenticationContext]::new()
            $c.ClientId        = $authConfig.servicePrincipal.clientId
            $c.HasClientSecret = [bool](Get-CIEMSecret 'CIEM_Azure_ClientSecret')
            $c
        }
        'ServicePrincipalCertificate' {
            $c = [CIEMAzureSPCertificateAuthenticationContext]::new()
            $c.ClientId          = $authConfig.servicePrincipal.clientId
            $c.HasCertThumbprint = [bool](Get-CIEMSecret 'CIEM_Azure_CertThumbprint')
            $c
        }
        'ManagedIdentity' {
            $c = [CIEMAzureManagedIdentityAuthenticationContext]::new()
            $c.ManagedIdentityClientId = $authConfig.managedIdentity.clientId
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
            $c.Method = $authConfig.method
            $c
        }
    }

    # Common Azure properties
    $ctx.Enabled  = [bool]$script:Config.azure.enabled
    $ctx.TenantId = $authConfig.tenantId

    $ctx
}

function Get-AWSAuthenticationContextFromConfig {
    <#
    .SYNOPSIS
        Internal helper — builds a typed AWS auth context from config + secrets.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $authConfig = $script:Config.aws.authentication

    # Instantiate the correct subclass based on configured method
    $ctx = switch ($authConfig.method) {
        'CurrentProfile' {
            $c = [CIEMAWSCurrentProfileAuthenticationContext]::new()
            $c.Profile = $authConfig.profile
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
            $c.Method = $authConfig.method
            $c
        }
    }

    # Common AWS properties
    $ctx.Enabled = [bool]$script:Config.aws.enabled
    $ctx.Region  = $authConfig.region

    $ctx
}
