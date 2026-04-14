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

    @(
        New-UDListItem -Label 'Dashboard' -Icon (New-UDIcon -Icon 'Home') -Href '/ciem'
        New-UDListItem -Label 'Scan' -Icon (New-UDIcon -Icon 'Play') -Href '/ciem/scan'
        New-UDListItem -Label 'Scan History' -Icon (New-UDIcon -Icon 'ClockRotateLeft') -Href '/ciem/history'
        New-UDListItem -Label 'Identities' -Icon (New-UDIcon -Icon 'UserShield') -Href '/ciem/identities'
        New-UDListItem -Label 'Effective Permissions' -Icon (New-UDIcon -Icon 'Key') -Href '/ciem/effective-permissions'
        New-UDListItem -Label 'Attack Paths' -Icon (New-UDIcon -Icon 'Route') -Href '/ciem/attack-paths'
        New-UDListItem -Label 'Attack Path Patterns' -Icon (New-UDIcon -Icon 'InfoCircle') -Href '/ciem/attack-path-patterns'
        New-UDListItem -Label 'Environment' -Icon (New-UDIcon -Icon 'SiteMap') -Href '/ciem/environment'
        New-UDListItem -Label 'Configuration' -Icon (New-UDIcon -Icon 'Cog') -Href '/ciem/config'
        New-UDListItem -Label 'About' -Icon (New-UDIcon -Icon 'InfoCircle') -Href '/ciem/about'
    )
}
