function Update-CIEMScanRun {
    <#
    .SYNOPSIS
        Updates a CIEMScanRun with results and/or status, then persists it.
    .DESCRIPTION
        Attaches scan results to a ScanRun, updates its status (Completed/Failed),
        and persists the updated state to PSU cache.
    .PARAMETER ScanRun
        The CIEMScanRun object to update.
    .PARAMETER Status
        New status to set (Completed or Failed).
    .PARAMETER ScanResults
        Array of CIEMScanResult objects to attach.
    .PARAMETER ErrorMessage
        Error message to record (for Failed status).
    .OUTPUTS
        CIEMScanRun
        The updated ScanRun object.
    .EXAMPLE
        Update-CIEMScanRun -ScanRun $scanRun -Status Completed -ScanResults $results

        Marks a scan run as completed and attaches the results.
    .EXAMPLE
        Update-CIEMScanRun -ScanRun $scanRun -Status Failed -ErrorMessage 'Authentication failed'

        Marks a scan run as failed with an error message.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanRun])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [CIEMScanRun]$ScanRun,

        [Parameter()]
        [ValidateSet('Completed', 'Failed')]
        [string]$Status,

        [Parameter()]
        [CIEMScanResult[]]$ScanResults,

        [Parameter()]
        [string]$ErrorMessage
    )

    process {
        # Attach results if provided
        if ($ScanResults) {
            $ScanRun.ScanResults = $ScanResults
        }

        # Update status
        if ($Status -eq 'Completed') {
            $ScanRun.Complete()
        }
        elseif ($Status -eq 'Failed') {
            $ScanRun.Fail($ErrorMessage)
        }

        # Persist to cache
        Save-CIEMScanRun -ScanRun $ScanRun

        return $ScanRun
    }
}
