function Get-CIEMAuthenticationContext {
    <#
    .SYNOPSIS
        Returns the configured authentication context for cloud providers.

    .DESCRIPTION
        Reads authentication configuration from the provider database and
        dispatches to registered provider type callbacks to reconstruct
        full auth context objects (including secret probing when applicable).

        By default returns contexts for all providers. Use -Provider to filter
        to a specific provider.

    .PARAMETER Provider
        Optional. Return context for specific provider(s) only.

    .OUTPUTS
        [PSCustomObject] One auth context object per provider.

    .EXAMPLE
        Get-CIEMAuthenticationContext
        # Returns contexts for all providers

    .EXAMPLE
        Get-CIEMAuthenticationContext -Provider Azure
        # Returns context for a specific provider
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
        $reg = $script:ProviderTypes[$p.Name]
        if ($reg -and $reg.ReadAuth) {
            # Pass the provider's Authentication object (has the same properties ReadAuth knows about)
            # with IncludeSecrets = $true to probe PSU secret store
            & $reg.ReadAuth $p.Authentication $true
        }
        else {
            # Unregistered provider: return generic context
            [PSCustomObject]@{
                Provider = $p.Name
                Enabled  = $p.Enabled
                Method   = $p.Authentication.Method
            }
        }
    }
}
