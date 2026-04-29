function New-CIEMNavigation {
    <#
    .SYNOPSIS
        Creates the sidebar navigation items for the CIEM app.
    .OUTPUTS
        System.Object[]
        Array of UDListItem components for the app navigation.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $ErrorActionPreference = 'Stop'

    foreach ($page in GetCIEMPSUPageRegistry) {
        New-UDListItem -Label ([string]$page.name) -Icon (New-UDIcon -Icon ([string]$page.icon)) -Href (GetCIEMPSUPageHref -Page $page)
    }
}
