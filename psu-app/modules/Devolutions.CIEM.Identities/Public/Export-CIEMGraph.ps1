function Export-CIEMGraph {
    <#
    .SYNOPSIS
        Serializes a CIEMGraph for PSU cache storage or file export.

    .DESCRIPTION
        Converts the CIEMGraph to a PSCustomObject suitable for Set-PSUCache
        or JSON export. Includes graph metadata (build time, node/edge counts).

    .PARAMETER Graph
        The CIEMGraph to export. Accepts either a [CIEMGraph] instance or a
        PSCustomObject with a ToPSCustomObject() method.

    .PARAMETER Path
        Optional file path to export as JSON. If not specified, returns the
        PSCustomObject directly (for PSU cache storage).

    .OUTPUTS
        [PSCustomObject] When -Path is not specified.

    .EXAMPLE
        $exported = Export-CIEMGraph -Graph $graph
        Set-PSUCache -Key 'CIEM:Graph:Latest' -Value $exported

    .EXAMPLE
        Export-CIEMGraph -Graph $graph -Path './graph-export.json'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Graph,

        [Parameter()]
        [string]$Path
    )
    $ErrorActionPreference = 'Stop'

    $exported = if ($Graph.PSObject.Methods.Name -contains 'ToPSCustomObject') {
        $Graph.ToPSCustomObject()
    } else {
        $Graph
    }

    if ($Path) {
        $exported | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding utf8
        Write-Verbose "Graph exported to: $Path"
    }
    else {
        return $exported
    }
}
