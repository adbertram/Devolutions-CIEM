function Get-CIEMAzureResourceRelationship {
    [CmdletBinding()]
    [OutputType('CIEMAzureResourceRelationship[]')]
    param(
        [Parameter()][int]$Id,
        [Parameter()][string]$SourceId,
        [Parameter()][string]$TargetId,
        [Parameter()][string]$RelationshipType
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('SourceId')) { $conditions += "source_id = @source_id"; $params.source_id = $SourceId }
    if ($PSBoundParameters.ContainsKey('TargetId')) { $conditions += "target_id = @target_id"; $params.target_id = $TargetId }
    if ($PSBoundParameters.ContainsKey('RelationshipType')) { $conditions += "relationship_type = @relationship_type"; $params.relationship_type = $RelationshipType }
    $query = "SELECT * FROM azure_resource_relationships"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureResourceRelationship]::new()
        $obj.Id = [int]$row.id; $obj.SourceId = $row.source_id; $obj.TargetId = $row.target_id
        $obj.RelationshipType = $row.relationship_type; $obj.Properties = $row.properties
        $obj.CollectedAt = if ($row.collected_at) { [datetime]$row.collected_at } else { Get-Date }
        $obj
    })
}
