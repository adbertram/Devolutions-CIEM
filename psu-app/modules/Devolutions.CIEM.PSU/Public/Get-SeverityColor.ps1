function Get-SeverityColor {
    <#
    .SYNOPSIS
        Returns the display color hex code for a severity or risk level.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Severity
    )

    $ErrorActionPreference = 'Stop'

    switch ($Severity.ToUpper()) {
        'CRITICAL' { '#9c27b0' }
        'HIGH'     { '#f44336' }
        'MEDIUM'   { '#ff9800' }
        'LOW'      { '#4caf50' }
        'INFO'     { '#2196f3' }
        default    { '#666' }
    }
}
