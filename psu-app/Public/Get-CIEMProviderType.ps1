function Get-CIEMProviderType {
    <#
    .SYNOPSIS
        Returns registered provider type names.

    .DESCRIPTION
        Returns the names of all provider types that have been registered
        via Register-CIEMProviderType. Used by argument completers and
        PSU pages to discover available providers.

    .PARAMETER Name
        Optional. Return a specific provider type registration.

    .OUTPUTS
        [string[]] Provider type names, or [hashtable] if -Name is specified.

    .EXAMPLE
        Get-CIEMProviderType
        # Returns @('Azure', 'AWS')

    .EXAMPLE
        Get-CIEMProviderType -Name 'Azure'
        # Returns the Azure registration hashtable
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name
    )

    if ($Name) {
        $script:ProviderTypes[$Name]
    }
    else {
        @($script:ProviderTypes.Keys)
    }
}
