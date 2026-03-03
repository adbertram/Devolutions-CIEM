function Remove-CIEMAzureSecurityPrincipal {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProvider')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureSecurityPrincipal[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) { if ($PSCmdlet.ShouldProcess($item.Id, 'Remove Azure security principal')) { Invoke-CIEMQuery -Query "DELETE FROM azure_security_principals WHERE id = @id" -Parameters @{ id = $item.Id } -AsNonQuery | Out-Null } }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByProvider') {
            if ($PSCmdlet.ShouldProcess("provider '$ProviderId'", 'Remove all Azure security principals')) { Invoke-CIEMQuery -Query "DELETE FROM azure_security_principals WHERE provider_id = @pid" -Parameters @{ pid = $ProviderId } -AsNonQuery | Out-Null }
        } else {
            if ($PSCmdlet.ShouldProcess($Id, 'Remove Azure security principal')) { Invoke-CIEMQuery -Query "DELETE FROM azure_security_principals WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null }
        }
    }
}
