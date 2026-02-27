function Import-CIEMGraph {
    <#
    .SYNOPSIS
        Deserializes a CIEMGraph from a PSCustomObject (e.g., from PSU cache).

    .DESCRIPTION
        Wrapper around [CIEMGraph]::FromPSCustomObject() for use outside the module scope.
        PowerShell classes defined via dot-sourcing are not accessible to callers via
        Import-Module, so this function provides access to the deserialization logic.

    .PARAMETER Data
        The PSCustomObject from Get-PSUCache or ConvertFrom-Json.

    .OUTPUTS
        [CIEMGraph] The deserialized graph object.

    .EXAMPLE
        $graphData = Get-PSUCache -Key 'CIEM:Graph:Latest'
        $graph = Import-CIEMGraph -Data $graphData
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Data
    )
    $ErrorActionPreference = 'Stop'

    return [CIEMGraph]::FromPSCustomObject($Data)
}
