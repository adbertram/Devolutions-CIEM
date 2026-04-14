function Assert-PSUConnection {
    <#
    .SYNOPSIS
        Validates that a PSU connection exists.

    .DESCRIPTION
        Checks the module-level connection state to ensure a valid connection
        to PowerShell Universal has been established via Connect-PSU. Throws
        a terminating error if no connection exists.
    #>
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    if (-not $script:PSUConnection.Url -or -not $script:PSUConnection.Token) {
        throw "Not connected to PSU. Run Connect-PSU first."
    }
}
