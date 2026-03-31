function New-CIEMGraphEdge {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a data record in database')]
    [OutputType('CIEMGraphEdge[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$SourceId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$TargetId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Kind,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Properties,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$Computed = 0,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $splat = @{
                    SourceId = $obj.SourceId
                    TargetId = $obj.TargetId
                    Kind     = $obj.Kind
                }
                if ($obj.Properties) { $splat.Properties = $obj.Properties }
                if ($null -ne $obj.Computed) { $splat.Computed = $obj.Computed }
                if ($obj.CollectedAt) { $splat.CollectedAt = $obj.CollectedAt }
                New-CIEMGraphEdge @splat
            }
            return
        }

        if (-not $CollectedAt) {
            $CollectedAt = (Get-Date).ToString('o')
        }

        Invoke-CIEMQuery -Query @"
INSERT INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at)
VALUES (@source_id, @target_id, @kind, @properties, @computed, @collected_at)
"@ -Parameters @{
            source_id    = $SourceId
            target_id    = $TargetId
            kind         = $Kind
            properties   = $Properties
            computed     = $Computed
            collected_at = $CollectedAt
        } -AsNonQuery | Out-Null

        $lastId = @(Invoke-CIEMQuery -Query "SELECT last_insert_rowid() as id")[0].id
        Get-CIEMGraphEdge -Id $lastId
    }
}
