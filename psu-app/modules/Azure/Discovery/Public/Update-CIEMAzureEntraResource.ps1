function Update-CIEMAzureEntraResource {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureEntraResource[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Type,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$DisplayName,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ParentId,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Properties,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [switch]$PassThru
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $parameters = @{
                    id           = $item.Id
                    type         = $item.Type
                    display_name = $item.DisplayName
                    parent_id    = $item.ParentId
                    properties   = $item.Properties
                    collected_at = $item.CollectedAt
                }
                Invoke-CIEMQuery -Query "UPDATE azure_entra_resources SET type = @type, display_name = @display_name, parent_id = @parent_id, properties = @properties, collected_at = @collected_at WHERE id = @id" -Parameters $parameters -AsNonQuery | Out-Null
                if ($PassThru) { Get-CIEMAzureEntraResource -Id $item.Id }
            }
        } else {
            $setClauses = @()
            $parameters = @{ id = $Id }
            $columnMap = @{
                Type        = 'type'
                DisplayName = 'display_name'
                ParentId    = 'parent_id'
                Properties  = 'properties'
                CollectedAt = 'collected_at'
            }

            foreach ($paramName in $columnMap.Keys) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $col = $columnMap[$paramName]
                    $setClauses += "$col = @$col"
                    $parameters[$col] = $PSBoundParameters[$paramName]
                }
            }

            if ($setClauses.Count -eq 0) {
                if ($PassThru) { Get-CIEMAzureEntraResource -Id $Id }
                return
            }

            Invoke-CIEMQuery -Query "UPDATE azure_entra_resources SET $($setClauses -join ', ') WHERE id = @id" -Parameters $parameters -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureEntraResource -Id $Id }
        }
    }
}
