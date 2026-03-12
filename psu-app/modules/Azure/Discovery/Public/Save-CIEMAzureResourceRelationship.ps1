function Save-CIEMAzureResourceRelationship {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$SourceId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$SourceType,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$TargetId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$TargetType,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Relationship,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(ParameterSetName = 'ByProperties')]
        $Connection,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $queryParams = @{
                    Query      = @"
INSERT OR REPLACE INTO azure_resource_relationships (source_id, source_type, target_id, target_type, relationship, collected_at)
VALUES (@source_id, @source_type, @target_id, @target_type, @relationship, @collected_at)
"@
                    Parameters = @{
                        source_id    = $obj.SourceId
                        source_type  = $obj.SourceType
                        target_id    = $obj.TargetId
                        target_type  = $obj.TargetType
                        relationship = $obj.Relationship
                        collected_at = $obj.CollectedAt
                    }
                    AsNonQuery = $true
                }
                if ($Connection) { $queryParams.Connection = $Connection }
                Invoke-CIEMQuery @queryParams | Out-Null
            }
        } else {
            $queryParams = @{
                Query      = @"
INSERT OR REPLACE INTO azure_resource_relationships (source_id, source_type, target_id, target_type, relationship, collected_at)
VALUES (@source_id, @source_type, @target_id, @target_type, @relationship, @collected_at)
"@
                Parameters = @{
                    source_id    = $SourceId
                    source_type  = $SourceType
                    target_id    = $TargetId
                    target_type  = $TargetType
                    relationship = $Relationship
                    collected_at = $CollectedAt
                }
                AsNonQuery = $true
            }
            if ($Connection) { $queryParams.Connection = $Connection }
            Invoke-CIEMQuery @queryParams | Out-Null
        }
    }
}
