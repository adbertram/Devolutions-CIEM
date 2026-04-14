function New-CIEMAzureEntraResource {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a resource record in database')]
    [OutputType('CIEMAzureEntraResource[]')]
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

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $parameters = @{
                    id           = $item.Id
                    type         = $item.Type
                    display_name = $item.DisplayName
                    parent_id    = $item.ParentId
                    properties   = $item.Properties
                    collected_at = if ($item.CollectedAt) { $item.CollectedAt } else { (Get-Date).ToString('o') }
                }
                Invoke-CIEMQuery -Query "INSERT INTO azure_entra_resources (id, type, display_name, parent_id, properties, collected_at) VALUES (@id, @type, @display_name, @parent_id, @properties, @collected_at)" -Parameters $parameters -AsNonQuery | Out-Null
                Get-CIEMAzureEntraResource -Id $item.Id
            }
        } else {
            $parameters = @{
                id           = $Id
                type         = $Type
                display_name = $DisplayName
                parent_id    = $ParentId
                properties   = $Properties
                collected_at = $CollectedAt
            }
            Invoke-CIEMQuery -Query "INSERT INTO azure_entra_resources (id, type, display_name, parent_id, properties, collected_at) VALUES (@id, @type, @display_name, @parent_id, @properties, @collected_at)" -Parameters $parameters -AsNonQuery | Out-Null
            Get-CIEMAzureEntraResource -Id $Id
        }
    }
}