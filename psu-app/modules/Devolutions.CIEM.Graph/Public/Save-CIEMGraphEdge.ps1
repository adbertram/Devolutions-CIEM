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

        $items = [System.Collections.Generic.List[object]]::new()
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $effectiveCollectedAt = if ([string]::IsNullOrWhiteSpace([string]$obj.CollectedAt)) {
                    (Get-Date).ToString('o')
                }
                else {
                    [string]$obj.CollectedAt
                }

                $effectiveComputed = if ($null -ne $obj.Computed) {
                    [int]$obj.Computed
                }
                else {
                    0
                }

                $items.Add(@{
                    SourceId    = $obj.SourceId
                    TargetId    = $obj.TargetId
                    Kind        = $obj.Kind
                    Properties  = $obj.Properties
                    Computed    = $effectiveComputed
                    CollectedAt = $effectiveCollectedAt
                })
            }
        }
        else {
            $effectiveCollectedAt = if ([string]::IsNullOrWhiteSpace($CollectedAt)) {
                (Get-Date).ToString('o')
            }
            else {
                $CollectedAt
            }

            $items.Add(@{
                SourceId    = $SourceId
                TargetId    = $TargetId
                Kind        = $Kind
                Properties  = $Properties
                Computed    = $Computed
                CollectedAt = $effectiveCollectedAt
            })
        }

        SaveCIEMGraphEntity -Entity Edge -Items $items.ToArray() -Connection $Connection
    }
}
