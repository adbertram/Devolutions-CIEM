function Remove-CIEMAzureResource {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProvider')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResource[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) { if ($PSCmdlet.ShouldProcess($item.Id, 'Remove Azure resource')) { Invoke-CIEMQuery -Query "DELETE FROM azure_resources WHERE id = @id" -Parameters @{ id = $item.Id } -AsNonQuery | Out-Null } }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByProvider') {
            if ($PSCmdlet.ShouldProcess("provider '$ProviderId'", 'Remove all Azure resources')) { Invoke-CIEMQuery -Query "DELETE FROM azure_resources WHERE provider_id = @pid" -Parameters @{ pid = $ProviderId } -AsNonQuery | Out-Null }
        } else {
            if ($PSCmdlet.ShouldProcess($Id, 'Remove Azure resource')) { Invoke-CIEMQuery -Query "DELETE FROM azure_resources WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null }
        }
    }
}
