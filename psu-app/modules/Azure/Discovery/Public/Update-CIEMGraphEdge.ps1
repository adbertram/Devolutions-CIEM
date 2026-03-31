function Update-CIEMGraphEdge {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMGraphEdge[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [int]$Id,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$SourceId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$TargetId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Kind,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Properties,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$Computed,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [switch]$PassThru
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $setClauses = @(); $params = @{ id = $obj.Id }
                $setClauses += "source_id = @source_id"; $params.source_id = $obj.SourceId
                $setClauses += "target_id = @target_id"; $params.target_id = $obj.TargetId
                $setClauses += "kind = @kind"; $params.kind = $obj.Kind
                $setClauses += "properties = @properties"; $params.properties = $obj.Properties
                $setClauses += "computed = @computed"; $params.computed = $obj.Computed
                $setClauses += "collected_at = @collected_at"; $params.collected_at = $obj.CollectedAt
                Invoke-CIEMQuery -Query "UPDATE graph_edges SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
                if ($PassThru) { Get-CIEMGraphEdge -Id $obj.Id }
            }
        } else {
            $setClauses = @(); $params = @{ id = $Id }
            $columnMap = @{
                SourceId    = 'source_id'
                TargetId    = 'target_id'
                Kind        = 'kind'
                Properties  = 'properties'
                Computed    = 'computed'
                CollectedAt = 'collected_at'
            }
            foreach ($paramName in $columnMap.Keys) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $col = $columnMap[$paramName]
                    $setClauses += "$col = @$col"
                    $params[$col] = $PSBoundParameters[$paramName]
                }
            }
            if ($setClauses.Count -gt 0) {
                Invoke-CIEMQuery -Query "UPDATE graph_edges SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            }
            if ($PassThru) { Get-CIEMGraphEdge -Id $Id }
        }
    }
}
