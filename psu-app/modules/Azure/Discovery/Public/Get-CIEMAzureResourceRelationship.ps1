function Get-CIEMAzureResourceRelationship {
    [CmdletBinding()]
    [OutputType('CIEMAzureResourceRelationship[]')]
    param(
        [Parameter()]
        [int]$Id,

        [Parameter()]
        [string]$SourceId,

        [Parameter()]
        [string]$SourceType,

        [Parameter()]
        [string]$TargetId,

        [Parameter()]
        [string]$TargetType,

        [Parameter()]
        [string]$Relationship
    )

    $query = "SELECT id, source_id, source_type, target_id, target_type, relationship, collected_at FROM azure_resource_relationships"
    $conditions = @()
    $parameters = @{}

    $columnMap = @{
        Id           = 'id'
        SourceId     = 'source_id'
        SourceType   = 'source_type'
        TargetId     = 'target_id'
        TargetType   = 'target_type'
        Relationship = 'relationship'
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
        $obj = [CIEMAzureResourceRelationship]::new()
        $obj.Id = $row.id
        $obj.SourceId = $row.source_id
        $obj.SourceType = $row.source_type
        $obj.TargetId = $row.target_id
        $obj.TargetType = $row.target_type
        $obj.Relationship = $row.relationship
        $obj.CollectedAt = $row.collected_at
        $obj
    })
}
