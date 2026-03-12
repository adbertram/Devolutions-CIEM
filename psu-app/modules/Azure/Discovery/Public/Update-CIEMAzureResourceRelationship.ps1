function Update-CIEMAzureResourceRelationship {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureResourceRelationship[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [int]$Id,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$SourceId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$SourceType,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$TargetId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$TargetType,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Relationship,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [switch]$PassThru
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $setClauses = @(); $params = @{ id = $obj.Id }
                $setClauses += "source_id = @source_id"; $params.source_id = $obj.SourceId
                $setClauses += "source_type = @source_type"; $params.source_type = $obj.SourceType
                $setClauses += "target_id = @target_id"; $params.target_id = $obj.TargetId
                $setClauses += "target_type = @target_type"; $params.target_type = $obj.TargetType
                $setClauses += "relationship = @relationship"; $params.relationship = $obj.Relationship
                $setClauses += "collected_at = @collected_at"; $params.collected_at = $obj.CollectedAt
                Invoke-CIEMQuery -Query "UPDATE azure_resource_relationships SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
                if ($PassThru) { Get-CIEMAzureResourceRelationship -Id $obj.Id }
            }
        } else {
            $setClauses = @(); $params = @{ id = $Id }
            $columnMap = @{
                SourceId     = 'source_id'
                SourceType   = 'source_type'
                TargetId     = 'target_id'
                TargetType   = 'target_type'
                Relationship = 'relationship'
                CollectedAt  = 'collected_at'
            }
            foreach ($paramName in $columnMap.Keys) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $col = $columnMap[$paramName]
                    $setClauses += "$col = @$col"
                    $params[$col] = $PSBoundParameters[$paramName]
                }
            }
            if ($setClauses.Count -gt 0) {
                Invoke-CIEMQuery -Query "UPDATE azure_resource_relationships SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            }
            if ($PassThru) { Get-CIEMAzureResourceRelationship -Id $Id }
        }
    }
}
