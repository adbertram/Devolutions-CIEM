function UpdateCIEMAzureResourceType {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureResourceType[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Type,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ApiSource,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$GraphTable,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$ResourceCount,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$DiscoveredAt,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$LastCollected,

        [Parameter(ParameterSetName = 'ByProperties')]
        [switch]$PassThru,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $parameters = @{
                    type           = $obj.Type
                    api_source     = $obj.ApiSource
                    graph_table    = $obj.GraphTable
                    resource_count = $obj.ResourceCount
                    discovered_at  = $obj.DiscoveredAt
                    last_collected = $obj.LastCollected
                }

                Invoke-CIEMQuery -Query @"
UPDATE azure_resource_types
SET api_source = @api_source, graph_table = @graph_table, resource_count = @resource_count,
    discovered_at = @discovered_at, last_collected = @last_collected
WHERE type = @type
"@ -Parameters $parameters -AsNonQuery | Out-Null
            }
            return
        }

        $columnMap = @{
            ApiSource      = 'api_source'
            GraphTable     = 'graph_table'
            ResourceCount  = 'resource_count'
            DiscoveredAt   = 'discovered_at'
            LastCollected  = 'last_collected'
        }

        $setClauses = @()
        $parameters = @{ type = $Type }

        foreach ($paramName in $columnMap.Keys) {
            if ($PSBoundParameters.ContainsKey($paramName)) {
                $col = $columnMap[$paramName]
                $setClauses += "$col = @$col"
                $parameters[$col] = $PSBoundParameters[$paramName]
            }
        }

        if ($setClauses.Count -eq 0) {
            if ($PassThru) { Get-CIEMAzureResourceType -Type $Type }
            return
        }

        $sql = "UPDATE azure_resource_types SET " + ($setClauses -join ', ') + " WHERE type = @type"
        Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null

        if ($PassThru) {
            Get-CIEMAzureResourceType -Type $Type
        }
    }
}
