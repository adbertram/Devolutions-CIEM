function Update-CIEMAzureResourceProperty {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([CIEMAzureResourceProperty])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ResourceId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Key,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Value,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResourceProperty[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) {
                $cRid = $item.ResourceId; $cKey = $item.Key
                $setClauses = @(); $params = @{ resource_id = $cRid; key = $cKey }
                $params.value = $item.Value; $setClauses += "value = @value"
            } else {
                $cRid = $ResourceId; $cKey = $Key
                $existing = Invoke-CIEMQuery -Query "SELECT resource_id FROM azure_resource_properties WHERE resource_id = @resource_id AND key = @key" -Parameters @{ resource_id = $cRid; key = $cKey }
                if (-not $existing) { throw "Azure resource property ('$cRid', '$cKey') not found." }
                $setClauses = @(); $params = @{ resource_id = $cRid; key = $cKey }
                if ($PSBoundParameters.ContainsKey('Value')) { $setClauses += "value = @value"; $params.value = $Value }
            }
            if ($setClauses.Count -eq 0) { if ($PassThru) { Get-CIEMAzureResourceProperty -ResourceId $cRid -Key $cKey }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_resource_properties SET $($setClauses -join ', ') WHERE resource_id = @resource_id AND key = @key" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureResourceProperty -ResourceId $cRid -Key $cKey }
        }
    }
}
