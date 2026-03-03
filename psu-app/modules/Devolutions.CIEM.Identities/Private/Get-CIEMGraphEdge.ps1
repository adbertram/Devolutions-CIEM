function Get-CIEMGraphEdge {
    <#
    .SYNOPSIS
        Queries edges in a CIEM graph by source, target, or relationship type.

    .PARAMETER Graph
        The CIEMGraph to query.

    .PARAMETER SourceId
        Filter edges originating from this node.

    .PARAMETER TargetId
        Filter edges targeting this node.

    .PARAMETER Relationship
        Filter edges by relationship type.

    .OUTPUTS
        [CIEMGraphEdge[]] Matching edges.
    #>
    [CmdletBinding()]
    [OutputType('CIEMGraphEdge[]')]
    param(
        [Parameter(Mandatory)]
        [CIEMGraph]$Graph,

        [Parameter()]
        [string]$SourceId,

        [Parameter()]
        [string]$TargetId,

        [Parameter()]
        [CIEMGraphRelationship]$Relationship
    )
    $ErrorActionPreference = 'Stop'

    $results = $Graph.Edges

    if ($PSBoundParameters.ContainsKey('SourceId')) {
        $results = @($results | Where-Object { $_.SourceId -eq $SourceId })
    }

    if ($PSBoundParameters.ContainsKey('TargetId')) {
        $results = @($results | Where-Object { $_.TargetId -eq $TargetId })
    }

    if ($PSBoundParameters.ContainsKey('Relationship')) {
        $results = @($results | Where-Object { $_.Relationship -eq $Relationship })
    }

    return @($results)
}
