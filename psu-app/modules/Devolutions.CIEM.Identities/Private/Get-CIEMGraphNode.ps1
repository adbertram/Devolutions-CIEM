function Get-CIEMGraphNode {
    <#
    .SYNOPSIS
        Queries nodes in a CIEM graph by type or property.

    .PARAMETER Graph
        The CIEMGraph to query.

    .PARAMETER Id
        Get a specific node by ID.

    .PARAMETER NodeType
        Filter nodes by type.

    .PARAMETER Property
        Property name to filter on.

    .PARAMETER Value
        Value to match for the property filter.

    .OUTPUTS
        [CIEMGraphNode[]] Matching nodes.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByType')]
    [OutputType([CIEMGraphNode[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMGraph]$Graph,

        [Parameter(ParameterSetName = 'ById')]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByType')]
        [CIEMGraphNodeType]$NodeType,

        [Parameter(ParameterSetName = 'ByProperty')]
        [string]$Property,

        [Parameter(ParameterSetName = 'ByProperty')]
        [string]$Value
    )
    $ErrorActionPreference = 'Stop'

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $node = $Graph.GetNode($Id)
        if ($node) { return @($node) }
        return @()
    }

    if ($PSCmdlet.ParameterSetName -eq 'ByType') {
        if ($PSBoundParameters.ContainsKey('NodeType')) {
            return $Graph.GetNodesByType($NodeType)
        }
        return @($Graph.Nodes.Values)
    }

    if ($PSCmdlet.ParameterSetName -eq 'ByProperty') {
        return @($Graph.Nodes.Values | Where-Object {
            $_.PSObject.Properties.Name -contains $Property -and
            $_.$Property -eq $Value
        })
    }
}
