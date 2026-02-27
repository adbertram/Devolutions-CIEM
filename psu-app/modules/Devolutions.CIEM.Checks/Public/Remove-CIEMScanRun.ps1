function Remove-CIEMScanRun {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProvider')]
        [string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [object[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $itemId = if ($item.Id) { $item.Id } else { $item }
                if ($PSCmdlet.ShouldProcess($itemId, 'Remove CIEM scan run')) {
                    Invoke-CIEMQuery -Query "DELETE FROM scan_runs WHERE id = @id" -Parameters @{ id = $itemId } -AsNonQuery | Out-Null
                }
            }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByProvider') {
            if ($PSCmdlet.ShouldProcess("provider '$ProviderId'", 'Remove all CIEM scan runs')) {
                Invoke-CIEMQuery -Query "DELETE FROM scan_runs WHERE provider_id = @pid" -Parameters @{ pid = $ProviderId } -AsNonQuery | Out-Null
            }
        } else {
            if ($PSCmdlet.ShouldProcess($Id, 'Remove CIEM scan run')) {
                Invoke-CIEMQuery -Query "DELETE FROM scan_runs WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
            }
        }
    }
}
