function Save-CIEMAzureEntraResource {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Type,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$DisplayName,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ParentId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Properties,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt = (Get-Date).ToString('o'),

        [Parameter(ParameterSetName = 'ByProperties')]
        [long]$LastSeenAt = 0,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    begin {
        $ErrorActionPreference = 'Stop'
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $items.Add([pscustomobject]@{
                    Id = $item.Id
                    Type = $item.Type
                    DisplayName = $item.DisplayName
                    ParentId = $item.ParentId
                    Properties = $item.Properties
                    CollectedAt = if ($item.CollectedAt) { $item.CollectedAt } else { (Get-Date).ToString('o') }
                    LastSeenAt = if ($item.PSObject.Properties.Name -contains 'LastSeenAt') { [long]$item.LastSeenAt } else { 0 }
                })
            }
            return
        }

        $items.Add([pscustomobject]@{
            Id = $Id
            Type = $Type
            DisplayName = $DisplayName
            ParentId = $ParentId
            Properties = $Properties
            CollectedAt = $CollectedAt
            LastSeenAt = $LastSeenAt
        })
    }

    end {
        if ($items.Count -eq 0) {
            return
        }

        SaveCIEMAzureTable -Entity 'EntraResource' -Items $items.ToArray() -Connection $Connection
    }
}
