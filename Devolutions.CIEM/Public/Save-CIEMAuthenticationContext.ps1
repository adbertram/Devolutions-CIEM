function Save-CIEMAuthenticationContext {
    <#
    .SYNOPSIS
        Saves authentication configuration for a cloud provider.

    .DESCRIPTION
        Single entry point for persisting provider authentication settings.
        Accepts simple string/bool parameters — typed context objects are created
        internally (avoids PS class scoping issues in PSU endpoint runspaces).
        Non-secret values are saved to the provider object via Update-CIEMProvider.
        Secret values are saved to PSU secrets via Set-CIEMSecret.

    .PARAMETER Provider
        Cloud provider name (e.g. 'Azure', 'AWS').

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

        # Secrets — stored in PSU secret store, never in provider object
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

    # Build the new Authentication PSCustomObject based on provider type
    $newAuth = $null

    switch ($Provider) {
        'Azure' {
            $newAuth = [PSCustomObject]@{
                Provider = 'Azure'
                Enabled  = $true
                Method   = $Method
                TenantId = $TenantId
                ClientId = $null
                ManagedIdentityClientId = $null
            }

            switch ($Method) {
                'ServicePrincipalSecret' {
                    $newAuth.ClientId = $ClientId
                    if ($ClientSecret) {
                        Set-CIEMSecret 'CIEM_Azure_ClientSecret' $ClientSecret
                        Write-CIEMLog -Message "Saved CIEM_Azure_ClientSecret to PSU secrets" -Severity DEBUG -Component 'Save-CIEMAuthContext'
                    }
                }
                'ServicePrincipalCertificate' {
                    $newAuth.ClientId = $ClientId
                    if ($CertThumbprint) {
                        Set-CIEMSecret 'CIEM_Azure_CertThumbprint' $CertThumbprint
                        Write-CIEMLog -Message "Saved CIEM_Azure_CertThumbprint to PSU secrets" -Severity DEBUG -Component 'Save-CIEMAuthContext'
                    }
                }
                'ManagedIdentity' {
                    $newAuth.ManagedIdentityClientId = $ManagedIdentityClientId
                }
            }
        }
        'AWS' {
            $newAuth = [PSCustomObject]@{
                Provider = 'AWS'
                Enabled  = $true
                Method   = $Method
                Profile  = $null
                Region   = $Region
            }

            switch ($Method) {
                'CurrentProfile' {
                    $newAuth.Profile = $Profile
                }
                'AccessKey' {
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
        default {
            $newAuth = [PSCustomObject]@{
                Provider = $Provider
                Enabled  = $true
                Method   = $Method
            }
        }
    }

    # Ensure provider exists, then update authentication and enable it
    $existing = Get-CIEMProvider -Name $Provider
    if (-not $existing) {
        Write-CIEMLog -Message "Provider '$Provider' not found, creating it" -Severity INFO -Component 'Save-CIEMAuthContext'
        New-CIEMProvider -Name $Provider | Out-Null
    }

    # Build a dummy auth context object for Update-CIEMProvider
    # We pass the PSCustomObject directly since Update-CIEMProvider handles both
    Update-CIEMProvider -Name $Provider -Enabled $true -Authentication $newAuth | Out-Null

    # Refresh module-level config
    $script:Config = Get-CIEMConfig

    Write-CIEMLog -Message "Save-CIEMAuthenticationContext completed for $Provider" -Severity INFO -Component 'Save-CIEMAuthContext'
}
