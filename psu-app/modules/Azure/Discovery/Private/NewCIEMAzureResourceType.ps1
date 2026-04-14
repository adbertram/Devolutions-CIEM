function NewCIEMAzureResourceType {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper, creates a data record in database')]
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
        [PSObject[]]$InputObject
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                NewCIEMAzureResourceType `
                    -Type $obj.Type `
                    -ApiSource $obj.ApiSource `
                    -GraphTable $obj.GraphTable `
                    -ResourceCount $obj.ResourceCount `
                    -DiscoveredAt $obj.DiscoveredAt `
                    -LastCollected $obj.LastCollected
            }
            return
        }

        if (-not $DiscoveredAt) {
            $DiscoveredAt = (Get-Date).ToString('o')
        }

        Invoke-CIEMQuery -Query @"
INSERT INTO azure_resource_types (type, api_source, graph_table, resource_count, discovered_at, last_collected)
VALUES (@type, @api_source, @graph_table, @resource_count, @discovered_at, @last_collected)
"@ -Parameters @{
            type           = $Type
            api_source     = $ApiSource
            graph_table    = $GraphTable
            resource_count = $ResourceCount
            discovered_at  = $DiscoveredAt
            last_collected = $LastCollected
        } -AsNonQuery | Out-Null

        Get-CIEMAzureResourceType -Type $Type
    }
}