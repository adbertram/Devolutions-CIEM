function Get-CIEMScanResult {
    <#
    .SYNOPSIS
        Retrieves scan results for a specific ScanRun from the database.
    .DESCRIPTION
        Retrieves the scan results for a given ScanRunId and reconstructs check
        metadata from provider catalogs.
    .PARAMETER ScanRunId
        The ID of the ScanRun to get results for (required).
    .EXAMPLE
        $scanRun = Get-CIEMScanRun | Select-Object -First 1
        $results = Get-CIEMScanResult -ScanRunId $scanRun.Id
    .EXAMPLE
        $failed = Get-CIEMScanResult -ScanRunId $scanRun.Id | Where-Object { $_.Status -eq 'FAIL' }
    .OUTPUTS
        [PSCustomObject[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScanRunId
    )

    $ErrorActionPreference = 'Stop'

    $rows = @(Invoke-CIEMQuery -Query @"
SELECT sr.status, sr.status_extended, sr.resource_id, sr.resource_name, sr.location,
       sr.check_id, scs.snapshot_json
FROM scan_results sr
LEFT JOIN scan_run_check_snapshots scs
  ON scs.scan_run_id = sr.scan_run_id
 AND scs.check_id = sr.check_id
WHERE sr.scan_run_id = @scan_run_id
"@ -Parameters @{ scan_run_id = $ScanRunId })

    if ($rows.Count -eq 0) {
        Write-Verbose "No results found for ScanRunId: $ScanRunId"
        return @()
    }

    $results = @(foreach ($row in $rows) {
        $check = if (-not [string]::IsNullOrWhiteSpace([string]$row.snapshot_json)) {
            ConvertFromCIEMCheckSnapshotJson -SnapshotJson $row.snapshot_json -Context "scan run '$ScanRunId' check '$($row.check_id)'"
        }
        else {
            $catalogCheck = @(Get-CIEMCheck -CheckId $row.check_id)
            if ($catalogCheck.Count -eq 0) {
                throw "Scan result references unknown catalog check '$($row.check_id)'."
            }
            $catalogCheck[0]
        }
        [PSCustomObject]@{
            Check = [PSCustomObject]@{
                Id          = $check.Id
                Provider    = $check.Provider
                Service     = $check.Service
                Title       = $check.Title
                Description = $check.Description
                Risk        = $check.Risk
                Severity    = $check.Severity
                Remediation = [PSCustomObject]@{
                    Text = $check.Remediation.Text
                    Url  = $check.Remediation.Url
                }
                RelatedUrl      = $check.RelatedUrl
                CheckScript     = $check.CheckScript
                ExecutionMode   = $check.ExecutionMode
                ManualReason    = $check.ManualReason
                Evaluator       = $check.Evaluator
                EvaluatorConfig = $check.EvaluatorConfig
                DependsOn       = @($check.DependsOn)
                DataNeeds       = if ($null -ne $check.DataNeeds) { @($check.DataNeeds) } else { $null }
                Disabled        = [bool]$check.Disabled
                Permissions     = $check.Permissions
            }
            Status         = $row.status
            StatusExtended = $row.status_extended
            ResourceId     = $row.resource_id
            ResourceName   = $row.resource_name
            Location       = $row.location
        }
    })

    $results
}
