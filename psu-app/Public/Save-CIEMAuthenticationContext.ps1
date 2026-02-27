function Save-CIEMAuthenticationContext {
    <#
    .SYNOPSIS
        Saves authentication configuration for a cloud provider.

    .DESCRIPTION
        Single entry point for persisting provider authentication settings.
        Accepts simple string/bool parameters -- typed context objects are created
        internally via the registered provider type's BuildAuth callback (avoids
        PS class scoping issues in PSU endpoint runspaces).

        Non-secret values are saved to the provider object via Update-CIEMProvider.
        Secret values are handled by the provider type's BuildAuth callback.

    .PARAMETER Provider
        Cloud provider name (e.g. 'Azure', 'AWS').

    .PARAMETER Method
        Authentication method (e.g. 'ServicePrincipalSecret', 'AccessKey').

    .PARAMETER TenantId
        Tenant ID (provider-specific).

    .PARAMETER ClientId
        Client/application ID (provider-specific).

    .PARAMETER ManagedIdentityClientId
        Managed identity client ID (provider-specific, null = system-assigned).

    .PARAMETER Region
        Cloud region (provider-specific).

    .PARAMETER Profile
        CLI profile name (provider-specific).

    .PARAMETER ClientSecret
        Client secret. Stored as PSU secret by the provider callback.

    .PARAMETER CertThumbprint
        Certificate thumbprint. Stored as PSU secret by the provider callback.

    .PARAMETER AccessKeyId
        Access key ID. Stored as PSU secret by the provider callback.

    .PARAMETER SecretAccessKey
        Secret access key. Stored as PSU secret by the provider callback.

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

        # Provider-specific non-secret params (callbacks pick what they need from $PSBoundParameters)
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [string]$ClientId,

        [Parameter()]
        [string]$ManagedIdentityClientId,

        [Parameter()]
        [string]$Region,

        [Parameter()]
        [string]$Profile,

        # Secrets -- stored in PSU secret store by provider callbacks, never in provider object
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

    # Build the new Authentication PSCustomObject via registered provider type callback
    $reg = $script:ProviderTypes[$Provider]
    if ($reg -and $reg.BuildAuth) {
        $newAuth = & $reg.BuildAuth $PSBoundParameters
    }
    else {
        # Unregistered provider: generic auth
        $newAuth = [PSCustomObject]@{
            Provider = $Provider
            Enabled  = $true
            Method   = $Method
        }
    }

    # Ensure provider exists, then update authentication and enable it
    $existing = Get-CIEMProvider -Name $Provider
    if (-not $existing) {
        Write-CIEMLog -Message "Provider '$Provider' not found, creating it" -Severity INFO -Component 'Save-CIEMAuthContext'
        New-CIEMProvider -Name $Provider | Out-Null
    }

    # Update the provider with new auth and enable it
    Update-CIEMProvider -Name $Provider -Enabled $true -Authentication $newAuth | Out-Null

    # Refresh module-level config
    $script:Config = Get-CIEMConfig

    Write-CIEMLog -Message "Save-CIEMAuthenticationContext completed for $Provider" -Severity INFO -Component 'Save-CIEMAuthContext'
}
