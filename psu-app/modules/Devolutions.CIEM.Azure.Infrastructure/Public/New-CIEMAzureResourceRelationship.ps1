function New-CIEMAzureResourceRelationship {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType([CIEMAzureResourceRelationship[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$SourceId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$TargetId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$RelationshipType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Properties,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResourceRelationship[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) { $p = @{ source_id=$item.SourceId; target_id=$item.TargetId; relationship_type=$item.RelationshipType; properties=$item.Properties; now=$now }; $cSid=$item.SourceId; $cTid=$item.TargetId; $cRt=$item.RelationshipType }
            else { $p = @{ source_id=$SourceId; target_id=$TargetId; relationship_type=$RelationshipType; properties=$Properties; now=$now }; $cSid=$SourceId; $cTid=$TargetId; $cRt=$RelationshipType }
            $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_resource_relationships WHERE source_id = @source_id AND target_id = @target_id AND relationship_type = @relationship_type" -Parameters @{ source_id = $cSid; target_id = $cTid; relationship_type = $cRt }
            if ($existing) { throw "Azure resource relationship ('$cSid', '$cTid', '$cRt') already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_resource_relationships (source_id, target_id, relationship_type, properties, collected_at) VALUES (@source_id, @target_id, @relationship_type, @properties, @now)" -Parameters $p -AsNonQuery | Out-Null
            $inserted = Invoke-CIEMQuery -Query "SELECT * FROM azure_resource_relationships WHERE source_id = @source_id AND target_id = @target_id AND relationship_type = @relationship_type" -Parameters @{ source_id = $cSid; target_id = $cTid; relationship_type = $cRt }
            Get-CIEMAzureResourceRelationship -Id ([int]$inserted.id)
        }
    }
}
