function Get-SeverityColor {
    <#
    .SYNOPSIS
        Returns the display color hex code for a severity or risk level.
    .DESCRIPTION
        Looks up the severity in the module-scope severity catalog loaded from
        modules/Devolutions.CIEM.PSU/Data/severity_catalog.json. Unknown severities
        return '#666' (gray) as a safe visual fallback.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Severity
    )

    $ErrorActionPreference = 'Stop'

    $entry = $script:SeverityByName[$Severity.ToLower()]
    if (-not $entry) {
        throw "Unknown severity '$Severity'. Valid values: $($script:SeverityByName.Keys -join ', ')"
    }
    $entry.color
}
