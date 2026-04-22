function New-DevolutionsCIEMApp {
    <#
    .SYNOPSIS
        Creates the Devolutions CIEM PowerShell Universal App.
    .DESCRIPTION
        Returns a PSU dashboard for Cloud Infrastructure Entitlement Management.
        This function is called by PSU when the app is loaded via the -Module/-Command pattern.

        Page functions are defined in the Pages/ directory and dot-sourced at module load time.
    .EXAMPLE
        New-DevolutionsCIEMApp
    .NOTES
        This function is exported for PSU to invoke via New-PSUApp -Module -Command.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidReturnStatement', '', Justification = 'Return statements required for early exit in PSU OnClick handlers')]
    param()

    process {
        $ErrorActionPreference = 'Stop'

        $Navigation = New-CIEMNavigation

        New-UDApp -Title 'Devolutions CIEM' -Pages @(
            New-CIEMDashboardPage -Navigation $Navigation
            New-CIEMScanPage -Navigation $Navigation
            New-CIEMScanHistoryPage -Navigation $Navigation
            New-CIEMIdentitiesPage -Navigation $Navigation
            New-CIEMAttackPathsPage -Navigation $Navigation
            New-CIEMAttackPathPatternsPage -Navigation $Navigation

            New-CIEMEnvironmentPage -Navigation $Navigation
            New-CIEMConfigPage -Navigation $Navigation
            New-CIEMAboutPage -Navigation $Navigation
        ) -DefaultTheme 'Light' -HeaderContent {
            New-UDDynamic -Id 'ciemLastDiscoveryHeaderRegion' -Content {
                Devolutions.CIEM\New-CIEMLastDiscoveryHeader
            } -AutoRefresh -AutoRefreshInterval 60
        }
    }
}
