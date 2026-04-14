function Get-StatusColor {
    <#
    .SYNOPSIS
        Returns the display color hex code for a scan result status.
    .DESCRIPTION
        Looks up the status in the module-scope status catalog loaded from
        modules/Devolutions.CIEM.PSU/Data/status_catalog.json.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Status)

    $ErrorActionPreference = 'Stop'

    $entry = $script:StatusByName[$Status.ToLower()]
    if (-not $entry) {
        throw "Unknown status '$Status'. Valid values: $($script:StatusByName.Keys -join ', ')"
    }
    $entry.color
}
