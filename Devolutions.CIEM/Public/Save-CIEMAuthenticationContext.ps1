function Save-CIEMAuthenticationContext {
    <#
    .SYNOPSIS
        Saves authentication configuration for a cloud provider.

    .DESCRIPTION
        Single entry point for persisting provider authentication settings.
        Accepts simple string/bool parameters — typed context objects are created
        internally (avoids PS class scoping issues in PSU endpoint runspaces).
        Non-secret values are saved to PSU cache via Set-CIEMConfig. Secret
        values are saved to PSU secrets via Set-CIEMSecret.

    .PARAMETER Provider
        Cloud provider: 'Azure' or 'AWS'.

    .PARAMETER Method
        Authentication method (e.g. 'ServicePrincipalSecret', 'AccessKey').

    .PARAMETER TenantId
        Azure tenant ID.

    .PARAMETER ClientId
        Azure service principal client ID.

    .PARAMETER ManagedIdentityClientId
        Azure managed identity client ID (null = system-assigned).

    .PARAMETER Region
        AWS region.

    .PARAMETER Profile
        AWS CLI profile name.

    .PARAMETER ClientSecret
        Azure SP client secret. Stored as PSU secret.

    .PARAMETER CertThumbprint
        Azure certificate thumbprint. Stored as PSU secret.

    .PARAMETER AccessKeyId
        AWS access key ID. Stored as PSU secret.

    .PARAMETER SecretAccessKey
        AWS secret access key. Stored as PSU secret.

    .OUTPUTS
        None.

    .EXAMPLE
        Save-CIEMAuthenticationContext -Provider Azure -Method ServicePrincipalSecret `
            -TenantId '...' -ClientId '...' -ClientSecret '...'

    .EXAMPLE
        Save-CIEMAuthenticationContext -Provider AWS -Method AccessKey `
            -Region 'us-east-1' -AccessKeyId '...' -SecretAccessKey '...'
    #>
    [CmdletBinding()]
    param(
        # Simple params replace typed -Context object (avoids PS class scoping in PSU runspaces)
        [Parameter(Mandatory)]
        [ValidateSet('Azure', 'AWS')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Method,

        # Azure-specific non-secret params
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [string]$ClientId,

        [Parameter()]
        [string]$ManagedIdentityClientId,

        # AWS-specific non-secret params
        [Parameter()]
        [string]$Region,

        [Parameter()]
        [string]$Profile,

        # Secrets — stored in PSU secret store, never in config
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

    Write-CIEMLog -Message "Save-CIEMAuthenticationContext called for $Provider ($Method)" -Severity INFO -Component 'Save-CIEMAuthContext'

    # Build non-secret config settings (saved to PSU cache via Set-CIEMConfig)
    $configSettings = @{}

    switch ($Provider) {
        'Azure' {
            $configSettings['azure.enabled'] = $true
            $configSettings['azure.authentication.method'] = $Method

            # TenantId is common to all Azure auth methods
            if ($TenantId) {
                $configSettings['azure.authentication.tenantId'] = $TenantId
            }

            switch ($Method) {
                'ServicePrincipalSecret' {
                    $configSettings['azure.authentication.servicePrincipal.clientId'] = $ClientId
                    # Secret -> PSU secret store
                    if ($ClientSecret) {
                        Set-CIEMSecret 'CIEM_Azure_ClientSecret' $ClientSecret
                        Write-CIEMLog -Message "Saved CIEM_Azure_ClientSecret to PSU secrets" -Severity DEBUG -Component 'Save-CIEMAuthContext'
                    }
                }
                'ServicePrincipalCertificate' {
                    $configSettings['azure.authentication.servicePrincipal.clientId'] = $ClientId
                    # Secret -> PSU secret store
                    if ($CertThumbprint) {
                        Set-CIEMSecret 'CIEM_Azure_CertThumbprint' $CertThumbprint
                        Write-CIEMLog -Message "Saved CIEM_Azure_CertThumbprint to PSU secrets" -Severity DEBUG -Component 'Save-CIEMAuthContext'
                    }
                }
                'ManagedIdentity' {
                    $configSettings['azure.authentication.managedIdentity.clientId'] = $ManagedIdentityClientId
                }
                # DeviceCode / Interactive need no additional credentials
            }
        }
        'AWS' {
            $configSettings['aws.enabled'] = $true
            $configSettings['aws.authentication.method'] = $Method

            # Region is common to all AWS auth methods
            if ($Region) {
                $configSettings['aws.authentication.region'] = $Region
            }

            switch ($Method) {
                'CurrentProfile' {
                    $configSettings['aws.authentication.profile'] = $Profile
                }
                'AccessKey' {
                    # Secrets -> PSU secret store
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

    Write-CIEMLog -Message "Save-CIEMAuthenticationContext completed for $Provider" -Severity INFO -Component 'Save-CIEMAuthContext'
}
