function Initialize-CIEMPSUInstance {
    <#
    .SYNOPSIS
        Initializes CIEM database resources for an installed PSU module.

    .DESCRIPTION
        Public wrapper around the import-time setup entry point. PSU loads apps
        and scripts from the module's .universal resources as part of module
        installation, so this command does not register PSU resources itself.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [switch]$Integrated
    )

    $ErrorActionPreference = 'Stop'

    Invoke-CIEMPSUSetup
}
