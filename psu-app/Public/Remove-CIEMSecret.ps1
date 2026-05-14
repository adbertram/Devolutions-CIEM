function Remove-CIEMSecret {
    <#
    .SYNOPSIS
        Removes a secret from PSU's Secret: drive.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Remove-CIEMSecret wraps PSU variable deletion.')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
    if (-not $inPSUContext) {
        throw "Not running in PSU context - Secret: drive not available. Cannot remove secret '$Name'."
    }

    Remove-PSUVariable -Name $Name -RemoveSecret | Out-Null
}
