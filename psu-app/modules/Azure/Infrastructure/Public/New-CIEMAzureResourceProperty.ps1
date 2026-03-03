function New-CIEMAzureResourceProperty {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType('CIEMAzureResourceProperty[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ResourceId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Key,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Value,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResourceProperty[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) { $p = @{ resource_id=$item.ResourceId; key=$item.Key; value=$item.Value }; $cRid=$item.ResourceId; $cKey=$item.Key }
            else { $p = @{ resource_id=$ResourceId; key=$Key; value=$Value }; $cRid=$ResourceId; $cKey=$Key }
            $existing = Invoke-CIEMQuery -Query "SELECT resource_id FROM azure_resource_properties WHERE resource_id = @resource_id AND key = @key" -Parameters @{ resource_id = $cRid; key = $cKey }
            if ($existing) { throw "Azure resource property ('$cRid', '$cKey') already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_resource_properties (resource_id, key, value) VALUES (@resource_id, @key, @value)" -Parameters $p -AsNonQuery | Out-Null
            Get-CIEMAzureResourceProperty -ResourceId $cRid -Key $cKey
        }
    }
}
