function SaveCIEMAzureResourceType {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper, upsert operation for bulk data')]
    [OutputType('CIEMAzureResourceType[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Type,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$ApiSource,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$GraphTable,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$ResourceCount = 0,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$DiscoveredAt,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$LastCollected,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        $Connection
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $discoveredAt = if ($obj.DiscoveredAt) { $obj.DiscoveredAt } else { (Get-Date).ToString('o') }
                $parameters = @{
                    type           = $obj.Type
                    api_source     = $obj.ApiSource
                    graph_table    = $obj.GraphTable
                    resource_count = $obj.ResourceCount
                    discovered_at  = $discoveredAt
                    last_collected = $obj.LastCollected
                }

                $sql = @"
INSERT OR REPLACE INTO azure_resource_types (type, api_source, graph_table, resource_count, discovered_at, last_collected)
VALUES (@type, @api_source, @graph_table, @resource_count, @discovered_at, @last_collected)
"@

                if ($Connection) {
                    Invoke-CIEMQuery -Connection $Connection -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
                } else {
                    Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
                }
            }
            return
        }

        if (-not $DiscoveredAt) {
            $DiscoveredAt = (Get-Date).ToString('o')
        }

        $parameters = @{
            type           = $Type
            api_source     = $ApiSource
            graph_table    = $GraphTable
            resource_count = $ResourceCount
            discovered_at  = $DiscoveredAt
            last_collected = $LastCollected
        }

        $sql = @"
INSERT OR REPLACE INTO azure_resource_types (type, api_source, graph_table, resource_count, discovered_at, last_collected)
VALUES (@type, @api_source, @graph_table, @resource_count, @discovered_at, @last_collected)
"@

        if ($Connection) {
            Invoke-CIEMQuery -Connection $Connection -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        } else {
            Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        }
    }
}