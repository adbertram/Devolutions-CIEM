function Save-CIEMAzureResourceProperty {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ResourceId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Key,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Value,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResourceProperty[]]$InputObject
    )
    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) { $p = @{ resource_id=$item.ResourceId; key=$item.Key; value=$item.Value } }
            else { $p = @{ resource_id=$ResourceId; key=$Key; value=$Value } }
            Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO azure_resource_properties (resource_id, key, value) VALUES (@resource_id, @key, @value)" -Parameters $p -AsNonQuery | Out-Null
        }
    }
}
