function Remove-CIEMScanResult {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [int]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByScanRun')]
        [string]$ScanRunId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [object[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $itemId = if ($item.Id) { $item.Id } elseif ($item.id) { $item.id } else { $item }
                if ($PSCmdlet.ShouldProcess("scan result $itemId", 'Remove')) {
                    Invoke-CIEMQuery -Query "DELETE FROM scan_results WHERE id = @id" -Parameters @{ id = $itemId } -AsNonQuery | Out-Null
                }
            }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByScanRun') {
            if ($PSCmdlet.ShouldProcess("scan run '$ScanRunId'", 'Remove all scan results')) {
                Invoke-CIEMQuery -Query "DELETE FROM scan_results WHERE scan_run_id = @id" -Parameters @{ id = $ScanRunId } -AsNonQuery | Out-Null
            }
        } else {
            if ($PSCmdlet.ShouldProcess("scan result $Id", 'Remove')) {
                Invoke-CIEMQuery -Query "DELETE FROM scan_results WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
            }
        }
    }
}
