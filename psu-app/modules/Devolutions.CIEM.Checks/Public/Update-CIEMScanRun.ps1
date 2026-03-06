function Update-CIEMScanRun {
    <#
    .SYNOPSIS
        Updates individual fields of an existing ScanRun.
    .DESCRIPTION
        Performs a partial UPDATE on the scan_runs table. Only fields explicitly
        passed via $PSBoundParameters are modified.
    .PARAMETER Id
        The ScanRun ID to update (required).
    .PARAMETER Status
        New status value.
    .PARAMETER ErrorMessage
        Error message to set (for failed scans).
    .PARAMETER PassThru
        Returns the updated ScanRun object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter()]
        [string]$Status,

        [Parameter()]
        [string]$ErrorMessage,

        [Parameter()]
        [switch]$PassThru
    )

    $ErrorActionPreference = 'Stop'

    $existing = Invoke-CIEMQuery -Query "SELECT id FROM scan_runs WHERE id = @id" -Parameters @{ id = $Id }
    if (-not $existing) {
        throw "ScanRun '$Id' not found."
    }

    $setClauses = @()
    $params = @{ id = $Id }

    if ($PSBoundParameters.ContainsKey('Status')) {
        $setClauses += "status = @status"
        $params.status = $Status
    }

    if ($PSBoundParameters.ContainsKey('ErrorMessage')) {
        $setClauses += "error_message = @error_message"
        $params.error_message = $ErrorMessage
    }

    if ($setClauses.Count -eq 0) {
        Write-Verbose "Update-CIEMScanRun: No fields to update."
        if ($PassThru) { return Get-CIEMScanRun -Id $Id }
        return
    }

    $query = "UPDATE scan_runs SET $($setClauses -join ', ') WHERE id = @id"
    Invoke-CIEMQuery -Query $query -Parameters $params -AsNonQuery | Out-Null

    if ($PassThru) { Get-CIEMScanRun -Id $Id }
}
