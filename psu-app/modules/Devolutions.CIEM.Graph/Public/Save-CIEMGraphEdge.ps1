function Save-CIEMGraphEdge {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
    [OutputType('CIEMGraphEdge[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$SourceId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$TargetId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Kind,

        [Parameter(ParameterSetName = 'ByProperties')]
        [AllowNull()]
        [string]$Properties = $null,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$Computed = 0,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    process {
        $ErrorActionPreference = 'Stop'
        $sql = @"
INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at)
VALUES (@source_id, @target_id, @kind, @properties, @computed, @collected_at)
"@

        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $collectedAt = if ($obj.CollectedAt) { $obj.CollectedAt } else { (Get-Date).ToString('o') }
                $computedVal = if ($null -ne $obj.Computed) { $obj.Computed } else { 0 }
                $queryParams = @{
                    Query      = $sql
                    Parameters = @{
                        source_id    = $obj.SourceId
                        target_id    = $obj.TargetId
                        kind         = $obj.Kind
                        properties   = $obj.Properties
                        computed     = $computedVal
                        collected_at = $collectedAt
                    }
                    AsNonQuery = $true
                }
                if ($Connection) { $queryParams.Connection = $Connection }
                Invoke-CIEMQuery @queryParams | Out-Null
            }
        } else {
            if (-not $CollectedAt) {
                $CollectedAt = (Get-Date).ToString('o')
            }

            $queryParams = @{
                Query      = $sql
                Parameters = @{
                    source_id    = $SourceId
                    target_id    = $TargetId
                    kind         = $Kind
                    properties   = $Properties
                    computed     = $Computed
                    collected_at = $CollectedAt
                }
                AsNonQuery = $true
            }
            if ($Connection) { $queryParams.Connection = $Connection }
            Invoke-CIEMQuery @queryParams | Out-Null
        }
    }
}
