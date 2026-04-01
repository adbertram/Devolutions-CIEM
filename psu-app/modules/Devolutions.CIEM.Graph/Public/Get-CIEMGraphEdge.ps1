function Get-CIEMGraphEdge {
    [CmdletBinding()]
    [OutputType('CIEMGraphEdge[]')]
    param(
        [Parameter()]
        [int]$Id,

        [Parameter()]
        [string]$SourceId,

        [Parameter()]
        [string]$TargetId,

        [Parameter()]
        [string]$Kind,

        [Parameter()]
        [int]$Computed
    )

    $ErrorActionPreference = 'Stop'

    $query = "SELECT id, source_id, target_id, kind, properties, computed, collected_at FROM graph_edges"
    $conditions = @()
    $parameters = @{}

    $columnMap = @{
        Id       = 'id'
        SourceId = 'source_id'
        TargetId = 'target_id'
        Kind     = 'kind'
        Computed = 'computed'
    }

    foreach ($paramName in $columnMap.Keys) {
        if ($PSBoundParameters.ContainsKey($paramName)) {
            $col = $columnMap[$paramName]
            $conditions += "$col = @$col"
            $parameters[$col] = $PSBoundParameters[$paramName]
        }
    }

    if ($conditions.Count -gt 0) {
        $query += "`nWHERE " + ($conditions -join ' AND ')
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        $obj = [CIEMGraphEdge]::new()
        $obj.Id = $row.id
        $obj.SourceId = $row.source_id
        $obj.TargetId = $row.target_id
        $obj.Kind = $row.kind
        $obj.Properties = $row.properties
        $obj.Computed = $row.computed
        $obj.CollectedAt = $row.collected_at
        $obj
    })
}
