function Update-CIEMAzureResourceRelationship {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([CIEMAzureResourceRelationship])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][int]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$SourceId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$TargetId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RelationshipType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Properties,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResourceRelationship[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $cId = $item.Id; $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $params.source_id = $item.SourceId; $setClauses += "source_id = @source_id"
                $params.target_id = $item.TargetId; $setClauses += "target_id = @target_id"
                $params.relationship_type = $item.RelationshipType; $setClauses += "relationship_type = @relationship_type"
                $params.properties = $item.Properties; $setClauses += "properties = @properties"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_resource_relationships WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure resource relationship '$cId' not found." }
                $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $colMap = @{ SourceId='source_id'; TargetId='target_id'; RelationshipType='relationship_type'; Properties='properties' }
                foreach ($pn in $colMap.Keys) {
                    if ($PSBoundParameters.ContainsKey($pn)) {
                        $col = $colMap[$pn]; $val = $PSBoundParameters[$pn]
                        $setClauses += "$col = @$col"; $params[$col] = $val
                    }
                }
            }
            if ($setClauses.Count -le 1) { if ($PassThru) { Get-CIEMAzureResourceRelationship -Id $cId }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_resource_relationships SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureResourceRelationship -Id $cId }
        }
    }
}
