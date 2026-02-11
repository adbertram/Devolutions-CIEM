function Save-CIEMAuthenticationContext {
    <#
    .SYNOPSIS
        Saves authentication configuration for a cloud provider.

    .DESCRIPTION
        Single entry point for persisting provider authentication settings.
        Accepts a typed CIEMAuthenticationContext object. Non-secret values
        (method, tenant ID, client ID, profile, region) are saved to PSU cache
        via Set-CIEMConfig. Secret values (client secret, access keys) are
        saved to PSU secrets via Set-CIEMSecret.

    .PARAMETER Context
        A CIEMAuthenticationContext subclass instance containing the provider
        credentials to save.

    .PARAMETER ClientSecret
        Azure SP client secret. Passed separately because secrets are never
        stored on the context object. Stored as PSU secret.

    .PARAMETER CertThumbprint
        Azure certificate thumbprint. Passed separately because secrets are
        never stored on the context object. Stored as PSU secret.

    .PARAMETER AccessKeyId
        AWS access key ID. Passed separately because secrets are never stored
        on the context object. Stored as PSU secret.

    .PARAMETER SecretAccessKey
        AWS secret access key. Passed separately because secrets are never
        stored on the context object. Stored as PSU secret.

    .OUTPUTS
        None.

    .EXAMPLE
        $ctx = [CIEMAzureSPAuthenticationContext]::new()
        $ctx.TenantId = '...'
        $ctx.ClientId = '...'
        Save-CIEMAuthenticationContext -Context $ctx -ClientSecret '...'

    .EXAMPLE
        $ctx = [CIEMAWSAccessKeyAuthenticationContext]::new()
        $ctx.Region = 'us-east-1'
        Save-CIEMAuthenticationContext -Context $ctx -AccessKeyId '...' -SecretAccessKey '...'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMAuthenticationContext]$Context,

        # Secrets are passed as separate params — never stored on the context object
        [Parameter()]
        [string]$ClientSecret,

        [Parameter()]
        [string]$CertThumbprint,

        [Parameter()]
        [string]$AccessKeyId,

        [Parameter()]
        [string]$SecretAccessKey
    )

    $ErrorActionPreference = 'Stop'

    $provider = $Context.Provider
    $method   = $Context.Method

    Write-CIEMLog -Message "Save-CIEMAuthenticationContext called for $provider ($method)" -Severity INFO -Component 'Save-CIEMAuthContext'

    # Build non-secret config settings (saved to PSU cache via Set-CIEMConfig)
    $configSettings = @{}

    switch ($provider) {
        'Azure' {
            $configSettings['azure.enabled'] = $Context.Enabled
            $configSettings['azure.authentication.method'] = $method

            # TenantId is on all Azure context subclasses
            if ($Context -is [CIEMAzureAuthenticationContext]) {
                $configSettings['azure.authentication.tenantId'] = $Context.TenantId
            }

            switch ($method) {
                'ServicePrincipalSecret' {
                    $configSettings['azure.authentication.servicePrincipal.clientId'] = $Context.ClientId
                    # Secret → PSU secret store
                    if ($ClientSecret) {
                        Set-CIEMSecret 'CIEM_Azure_ClientSecret' $ClientSecret
                        Write-CIEMLog -Message "Saved CIEM_Azure_ClientSecret to PSU secrets" -Severity DEBUG -Component 'Save-CIEMAuthContext'
                    }
                }
                'ServicePrincipalCertificate' {
                    $configSettings['azure.authentication.servicePrincipal.clientId'] = $Context.ClientId
                    # Secret → PSU secret store
                    if ($CertThumbprint) {
                        Set-CIEMSecret 'CIEM_Azure_CertThumbprint' $CertThumbprint
                        Write-CIEMLog -Message "Saved CIEM_Azure_CertThumbprint to PSU secrets" -Severity DEBUG -Component 'Save-CIEMAuthContext'
                    }
                }
                'ManagedIdentity' {
                    $configSettings['azure.authentication.managedIdentity.clientId'] = $Context.ManagedIdentityClientId
                }
                # DeviceCode / Interactive need no additional credentials
            }
        }
        'AWS' {
            $configSettings['aws.enabled'] = $Context.Enabled
            $configSettings['aws.authentication.method'] = $method

            # Region is on all AWS context subclasses
            if ($Context -is [CIEMAWSAuthenticationContext]) {
                $configSettings['aws.authentication.region'] = $Context.Region
            }

            switch ($method) {
                'CurrentProfile' {
                    $configSettings['aws.authentication.profile'] = $Context.Profile
                }
                'AccessKey' {
                    # Secrets → PSU secret store
                    if ($AccessKeyId) {
                        Set-CIEMSecret 'CIEM_AWS_AccessKeyId' $AccessKeyId
                        Write-CIEMLog -Message "Saved CIEM_AWS_AccessKeyId to PSU secrets" -Severity DEBUG -Component 'Save-CIEMAuthContext'
                    }
                    if ($SecretAccessKey) {
                        Set-CIEMSecret 'CIEM_AWS_SecretAccessKey' $SecretAccessKey
                        Write-CIEMLog -Message "Saved CIEM_AWS_SecretAccessKey to PSU secrets" -Severity DEBUG -Component 'Save-CIEMAuthContext'
                    }
                }
            }
        }
    }

    # Persist non-secret config to PSU cache
    if ($configSettings.Count -gt 0) {
        Set-CIEMConfig -Settings $configSettings
        Write-CIEMLog -Message "Config settings saved: $($configSettings.Keys -join ', ')" -Severity INFO -Component 'Save-CIEMAuthContext'
    }

    Write-CIEMLog -Message "Save-CIEMAuthenticationContext completed for $provider" -Severity INFO -Component 'Save-CIEMAuthContext'
}
