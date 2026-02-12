function Update-CIEMProvider {
    <#
    .SYNOPSIS
        Updates an existing CIEM cloud provider.

    .DESCRIPTION
        Modifies properties of a provider in the CIEM:Providers cache.
        Only specified parameters are updated; unspecified ones are preserved.

    .PARAMETER Name
        Provider name to update (case-insensitive).

    .PARAMETER Enabled
        Whether the provider is enabled.

    .PARAMETER IsDefault
        Set this provider as the default. Clears IsDefault on all others.

    .PARAMETER Authentication
        New CIEMAuthenticationContext object.

    .PARAMETER Endpoints
        New PSCustomObject with provider-specific API endpoints.

    .PARAMETER ResourceFilter
        New array of subscription IDs or account IDs.

    .OUTPUTS
        [PSCustomObject] The updated provider object with computed CheckCount.

    .EXAMPLE
        Update-CIEMProvider -Name 'GCP' -Enabled $true

    .EXAMPLE
        Update-CIEMProvider -Name 'Azure' -IsDefault
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [bool]$Enabled,

        [Parameter()]
        [switch]$IsDefault,

        [Parameter()]
        [object]$Authentication,

        [Parameter()]
        [PSCustomObject]$Endpoints,

        [Parameter()]
        [string[]]$ResourceFilter
    )

    $ErrorActionPreference = 'Stop'

    # Load existing providers
    $providers = @(Get-CIEMProvider)

    # Find the target provider
    $target = $providers | Where-Object { $_.Name -eq $Name }
    if (-not $target) {
        throw "Provider '$Name' not found. Use New-CIEMProvider to create it."
    }

    # Update only specified parameters
    if ($PSBoundParameters.ContainsKey('Enabled')) {
        $target.Enabled = $Enabled
        # Also update auth context Enabled flag
        if ($target.Authentication) {
            $target.Authentication | Add-Member -NotePropertyName 'Enabled' -NotePropertyValue $Enabled -Force
        }
    }

    if ($PSBoundParameters.ContainsKey('Authentication')) {
        # Serialize auth context if it's a class instance
        if ($Authentication -is [CIEMAuthenticationContext]) {
            $authObj = [PSCustomObject]@{
                Provider = $Authentication.Provider
                Enabled  = $Authentication.Enabled
                Method   = $Authentication.Method
            }
            foreach ($prop in $Authentication.PSObject.Properties) {
                if ($prop.Name -notin @('Provider', 'Enabled', 'Method')) {
                    $authObj | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                }
            }
            $target | Add-Member -NotePropertyName 'Authentication' -NotePropertyValue $authObj -Force
        }
        else {
            $target | Add-Member -NotePropertyName 'Authentication' -NotePropertyValue $Authentication -Force
        }
    }

    if ($PSBoundParameters.ContainsKey('Endpoints')) {
        $target | Add-Member -NotePropertyName 'Endpoints' -NotePropertyValue $Endpoints -Force
    }

    if ($PSBoundParameters.ContainsKey('ResourceFilter')) {
        $target | Add-Member -NotePropertyName 'ResourceFilter' -NotePropertyValue $ResourceFilter -Force
    }

    if ($IsDefault.IsPresent) {
        # Clear IsDefault on all others
        foreach ($p in $providers) {
            $p | Add-Member -NotePropertyName 'IsDefault' -NotePropertyValue ($p.Name -eq $Name) -Force
        }
    }

    # Remove computed CheckCount before persisting (it's added by Get-CIEMProvider)
    $toCache = $providers | ForEach-Object {
        $obj = [PSCustomObject]@{
            Name           = $_.Name
            Enabled        = $_.Enabled
            IsDefault      = $_.IsDefault
            Authentication = $_.Authentication
            Endpoints      = $_.Endpoints
            ResourceFilter = @($_.ResourceFilter)
        }
        $obj
    }

    # Persist to PSU cache
    Set-PSUCache -Key 'CIEM:Providers' -Value @($toCache) -ErrorAction SilentlyContinue

    # Return the updated provider with CheckCount
    Get-CIEMProvider -Name $Name
}
