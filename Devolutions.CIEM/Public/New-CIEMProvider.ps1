function New-CIEMProvider {
    <#
    .SYNOPSIS
        Creates a new CIEM cloud provider.

    .DESCRIPTION
        Adds a new provider to the CIEM:Providers cache. Validates name
        uniqueness and applies sensible defaults for known providers
        (Azure, AWS). For unknown providers, creates a base configuration.

    .PARAMETER Name
        Provider name (e.g., 'Azure', 'AWS', 'GCP'). Must be unique.

    .PARAMETER Enabled
        Whether the provider is enabled. Defaults to $true.

    .PARAMETER IsDefault
        Set this provider as the default. Clears IsDefault on all others.

    .PARAMETER Authentication
        Optional CIEMAuthenticationContext object. If not specified, creates
        a default auth context for known providers.

    .PARAMETER Endpoints
        Optional PSCustomObject with provider-specific API endpoints.

    .PARAMETER ResourceFilter
        Optional array of subscription IDs or account IDs to filter.

    .OUTPUTS
        [PSCustomObject] The new provider object with computed CheckCount.

    .EXAMPLE
        New-CIEMProvider -Name 'GCP'

    .EXAMPLE
        New-CIEMProvider -Name 'Azure' -Enabled $true -IsDefault
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a configuration object in cache, not a system resource')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [bool]$Enabled = $true,

        [Parameter()]
        [switch]$IsDefault,

        [Parameter()]
        [CIEMAuthenticationContext]$Authentication,

        [Parameter()]
        [PSCustomObject]$Endpoints,

        [Parameter()]
        [string[]]$ResourceFilter
    )

    $ErrorActionPreference = 'Stop'

    # Load existing providers from cache (or defaults)
    $providers = @(Get-CIEMProvider)

    # Validate name uniqueness (case-insensitive)
    $existing = $providers | Where-Object { $_.Name -eq $Name }
    if ($existing) {
        throw "Provider '$Name' already exists. Use Update-CIEMProvider to modify it."
    }

    # Build new provider
    $provider = [CIEMProvider]::new($Name)
    $provider.Enabled = $Enabled

    # Set authentication context
    if ($Authentication) {
        $provider.Authentication = $Authentication
    }
    else {
        # Create default auth context for known providers
        switch ($Name) {
            'Azure' {
                $auth = [CIEMAzureAuthenticationContext]::new()
                $auth.Method = 'ServicePrincipalSecret'
                $auth.Enabled = $Enabled
                $provider.Authentication = $auth
            }
            'AWS' {
                $auth = [CIEMAWSAuthenticationContext]::new()
                $auth.Method = 'CurrentProfile'
                $auth.Enabled = $Enabled
                $provider.Authentication = $auth
            }
            default {
                $auth = [CIEMAuthenticationContext]::new()
                $auth.Provider = $Name
                $auth.Enabled = $Enabled
                $provider.Authentication = $auth
            }
        }
    }

    # Set endpoints
    if ($Endpoints) {
        $provider.Endpoints = $Endpoints
    }
    else {
        # Apply known-provider defaults
        switch ($Name) {
            'Azure' {
                $provider.Endpoints = [PSCustomObject]@{
                    graphApi = 'https://graph.microsoft.com/v1.0'
                    armApi   = 'https://management.azure.com'
                }
            }
        }
    }

    # Set resource filter
    if ($ResourceFilter) {
        $provider.ResourceFilter = $ResourceFilter
    }

    # Handle IsDefault: if this is the first provider or -IsDefault specified
    if ($IsDefault.IsPresent -or $providers.Count -eq 0) {
        $provider.IsDefault = $true
    }

    # Serialize provider
    $newProviderObj = $provider.ToPSCustomObject()

    # If this provider is default, clear IsDefault on others
    if ($newProviderObj.IsDefault) {
        foreach ($p in $providers) {
            $p | Add-Member -NotePropertyName 'IsDefault' -NotePropertyValue $false -Force
        }
    }

    # Build full provider list for persistence
    $allProviders = @($providers) + @($newProviderObj)

    # Persist to PSU cache
    Set-PSUCache -Key 'CIEM:Providers' -Value $allProviders -ErrorAction SilentlyContinue

    # Return the new provider with computed CheckCount
    $checksPath = Join-Path -Path $script:ModuleRoot -ChildPath "Checks/$Name"
    $checkCount = if (Test-Path $checksPath) { @(Get-ChildItem -Path "$checksPath/*.ps1").Count } else { 0 }
    $newProviderObj | Add-Member -NotePropertyName 'CheckCount' -NotePropertyValue $checkCount -Force
    $newProviderObj
}
