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

    @(
        New-UDListItem -Label 'Dashboard' -Icon (New-UDIcon -Icon 'Home') -Href '/ciem'
        New-UDListItem -Label 'Scan' -Icon (New-UDIcon -Icon 'Play') -Href '/ciem/scan'
        New-UDListItem -Label 'Scan History' -Icon (New-UDIcon -Icon 'ClockRotateLeft') -Href '/ciem/history'
        New-UDListItem -Label 'Configuration' -Icon (New-UDIcon -Icon 'Cog') -Href '/ciem/config'
        New-UDListItem -Label 'About' -Icon (New-UDIcon -Icon 'InfoCircle') -Href '/ciem/about'
    )
}
