function Save-CIEMAzureResourceRelationship {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    param(
        [Parameter(ParameterSetName = 'ByProperties')][int]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$SourceId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$TargetId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$RelationshipType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Properties,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResourceRelationship[]]$InputObject
    )
    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                if ($item.Id -gt 0) { $p = @{ id=$item.Id; source_id=$item.SourceId; target_id=$item.TargetId; relationship_type=$item.RelationshipType; properties=$item.Properties; now=$now }; Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO azure_resource_relationships (id, source_id, target_id, relationship_type, properties, collected_at) VALUES (@id, @source_id, @target_id, @relationship_type, @properties, @now)" -Parameters $p -AsNonQuery | Out-Null }
                else { $p = @{ source_id=$item.SourceId; target_id=$item.TargetId; relationship_type=$item.RelationshipType; properties=$item.Properties; now=$now }; Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO azure_resource_relationships (source_id, target_id, relationship_type, properties, collected_at) VALUES (@source_id, @target_id, @relationship_type, @properties, @now)" -Parameters $p -AsNonQuery | Out-Null }
            } else {
                if ($PSBoundParameters.ContainsKey('Id')) { $p = @{ id=$Id; source_id=$SourceId; target_id=$TargetId; relationship_type=$RelationshipType; properties=$Properties; now=$now }; Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO azure_resource_relationships (id, source_id, target_id, relationship_type, properties, collected_at) VALUES (@id, @source_id, @target_id, @relationship_type, @properties, @now)" -Parameters $p -AsNonQuery | Out-Null }
                else { $p = @{ source_id=$SourceId; target_id=$TargetId; relationship_type=$RelationshipType; properties=$Properties; now=$now }; Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO azure_resource_relationships (source_id, target_id, relationship_type, properties, collected_at) VALUES (@source_id, @target_id, @relationship_type, @properties, @now)" -Parameters $p -AsNonQuery | Out-Null }
            }
        }
    }
}
