function Remove-CIEMAzureResourceProperty {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')][string]$ResourceId,
        [Parameter(Mandatory, ParameterSetName = 'ById')][string]$Key,
        [Parameter(Mandatory, ParameterSetName = 'ByResourceId')][string]$ResourceIdFilter,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResourceProperty[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) { if ($PSCmdlet.ShouldProcess("('$($item.ResourceId)', '$($item.Key)')", 'Remove Azure resource property')) { Invoke-CIEMQuery -Query "DELETE FROM azure_resource_properties WHERE resource_id = @resource_id AND key = @key" -Parameters @{ resource_id = $item.ResourceId; key = $item.Key } -AsNonQuery | Out-Null } }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
            if ($PSCmdlet.ShouldProcess("resource '$ResourceIdFilter'", 'Remove all Azure resource properties')) { Invoke-CIEMQuery -Query "DELETE FROM azure_resource_properties WHERE resource_id = @resource_id" -Parameters @{ resource_id = $ResourceIdFilter } -AsNonQuery | Out-Null }
        } else {
            if ($PSCmdlet.ShouldProcess("('$ResourceId', '$Key')", 'Remove Azure resource property')) { Invoke-CIEMQuery -Query "DELETE FROM azure_resource_properties WHERE resource_id = @resource_id AND key = @key" -Parameters @{ resource_id = $ResourceId; key = $Key } -AsNonQuery | Out-Null }
        }
    }
}
