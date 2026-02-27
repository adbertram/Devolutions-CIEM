function Update-CIEMAzureResource {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([CIEMAzureResource])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Type,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ParentId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Name,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Location,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Tags,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResource[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $cId = $item.Id; $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $params.type = $item.Type; $setClauses += "type = @type"
                $params.parent_id = $item.ParentId; $setClauses += "parent_id = @parent_id"
                $params.name = $item.Name; $setClauses += "name = @name"
                $params.location = $item.Location; $setClauses += "location = @location"
                $params.tags = $item.Tags; $setClauses += "tags = @tags"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_resources WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure resource '$cId' not found." }
                $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $colMap = @{ Type='type'; ParentId='parent_id'; Name='name'; Location='location'; Tags='tags' }
                foreach ($pn in $colMap.Keys) {
                    if ($PSBoundParameters.ContainsKey($pn)) {
                        $col = $colMap[$pn]; $val = $PSBoundParameters[$pn]
                        $setClauses += "$col = @$col"; $params[$col] = $val
                    }
                }
            }
            if ($setClauses.Count -le 1) { if ($PassThru) { Get-CIEMAzureResource -Id $cId }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_resources SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureResource -Id $cId }
        }
    }
}
