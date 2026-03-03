function Remove-CIEMAzureResourceRelationship {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')][int]$Id,
        [Parameter(Mandatory, ParameterSetName = 'BySourceId')][string]$SourceId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResourceRelationship[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) { if ($PSCmdlet.ShouldProcess("id '$($item.Id)'", 'Remove Azure resource relationship')) { Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships WHERE id = @id" -Parameters @{ id = $item.Id } -AsNonQuery | Out-Null } }
        } elseif ($PSCmdlet.ParameterSetName -eq 'BySourceId') {
            if ($PSCmdlet.ShouldProcess("source '$SourceId'", 'Remove all Azure resource relationships')) { Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships WHERE source_id = @source_id" -Parameters @{ source_id = $SourceId } -AsNonQuery | Out-Null }
        } else {
            if ($PSCmdlet.ShouldProcess("id '$Id'", 'Remove Azure resource relationship')) { Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null }
        }
    }
}
