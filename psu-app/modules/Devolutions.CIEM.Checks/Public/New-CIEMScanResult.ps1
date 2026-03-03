function New-CIEMScanResult {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates scan result record')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ScanRunId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$CheckId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][ValidateSet('PASS','FAIL','MANUAL','SKIPPED')][string]$Status,
        [Parameter(ParameterSetName = 'ByProperties')][string]$StatusExtended,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ResourceId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ResourceName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Location,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMScanResult[]]$InputObject,
        [Parameter(ParameterSetName = 'InputObject')][string]$ForScanRunId
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $cScanRunId = if ($ForScanRunId) { $ForScanRunId } else { throw "ForScanRunId is required with InputObject" }
                $cCheckId = if ($item.Check.Id) { $item.Check.Id } else { $item.Check.id }
                Invoke-CIEMQuery -Query @"
INSERT INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name, location)
VALUES (@scan_run_id, @check_id, @status, @status_extended, @resource_id, @resource_name, @location)
"@ -Parameters @{
                    scan_run_id = $cScanRunId; check_id = $cCheckId; status = [string]$item.Status
                    status_extended = $item.StatusExtended; resource_id = $item.ResourceId
                    resource_name = $item.ResourceName; location = $item.Location
                } -AsNonQuery | Out-Null
            }
        } else {
            Invoke-CIEMQuery -Query @"
INSERT INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name, location)
VALUES (@scan_run_id, @check_id, @status, @status_extended, @resource_id, @resource_name, @location)
"@ -Parameters @{
                scan_run_id = $ScanRunId; check_id = $CheckId; status = $Status
                status_extended = $StatusExtended; resource_id = $ResourceId
                resource_name = $ResourceName; location = $Location
            } -AsNonQuery | Out-Null
        }
    }
}
