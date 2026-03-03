function Remove-CIEMCheck {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                if ($PSCmdlet.ShouldProcess($item.Id, 'Remove CIEM check')) {
                    Invoke-CIEMQuery -Query "DELETE FROM checks WHERE id = @id" -Parameters @{ id = $item.Id } -AsNonQuery | Out-Null
                }
            }
        } else {
            if ($PSCmdlet.ShouldProcess($Id, 'Remove CIEM check')) {
                Invoke-CIEMQuery -Query "DELETE FROM checks WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
            }
        }
    }
}
