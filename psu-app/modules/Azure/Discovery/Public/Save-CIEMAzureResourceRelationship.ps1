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

        [Parameter()]
        $Connection,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    begin {
        $ErrorActionPreference = 'Stop'
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $items.Add([pscustomobject]@{
                    SourceId = $item.SourceId
                    SourceType = $item.SourceType
                    TargetId = $item.TargetId
                    TargetType = $item.TargetType
                    Relationship = $item.Relationship
                    CollectedAt = $item.CollectedAt
                })
            }
            return
        }

        $items.Add([pscustomobject]@{
            SourceId = $SourceId
            SourceType = $SourceType
            TargetId = $TargetId
            TargetType = $TargetType
            Relationship = $Relationship
            CollectedAt = $CollectedAt
        })
    }

    end {
        if ($items.Count -eq 0) {
            return
        }

        SaveCIEMAzureTable -Entity 'ResourceRelationship' -Items $items.ToArray() -Connection $Connection
    }
}
