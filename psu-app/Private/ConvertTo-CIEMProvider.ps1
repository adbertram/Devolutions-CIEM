function ConvertTo-CIEMProvider {
    <#
    .SYNOPSIS
        Converts a PSCustomObject to a typed CIEMProvider instance.

    .DESCRIPTION
        Reconstructs a CIEMProvider class instance from a PSCustomObject,
        including the correct authentication context via registered provider
        type callbacks. Handles objects deserialized from PSU cache where
        class type information is lost.

    .PARAMETER InputObject
        The PSCustomObject (or CIEMProvider) to convert.

    .OUTPUTS
        [CIEMProvider]
    #>
    [CmdletBinding()]
    [OutputType('CIEMProvider')]
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
        $provider.ResourceFilter = @($InputObject.ResourceFilter)

        # Reconstruct the authentication context via registered provider type callback
        $authRaw = $InputObject.Authentication
        $authProvider = if ($authRaw.Provider) { $authRaw.Provider } else { $InputObject.Name }

        $reg = $script:ProviderTypes[$authProvider]
        if ($reg -and $reg.ReadAuth) {
            $provider.Authentication = & $reg.ReadAuth $authRaw $false
        }
        else {
            # Unregistered type: generic auth
            $authMethod = if ($authRaw.Method) { $authRaw.Method } else { '' }
            $provider.Authentication = [PSCustomObject]@{
                Provider = $authProvider
                Enabled  = [bool]$authRaw.Enabled
                Method   = $authMethod
            }
        }

        # Endpoints from registered defaults or keep from InputObject
        if ($InputObject.Endpoints) {
            $provider.Endpoints = $InputObject.Endpoints
        }
        elseif ($reg -and $reg.DefaultEndpoints) {
            $provider.Endpoints = $reg.DefaultEndpoints
        }
        else {
            $provider.Endpoints = [PSCustomObject]@{}
        }

        $provider
    }
}
