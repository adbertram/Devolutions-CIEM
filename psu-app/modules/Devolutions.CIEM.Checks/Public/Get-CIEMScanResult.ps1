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
       sr.check_id
FROM scan_results sr
WHERE sr.scan_run_id = @scan_run_id
"@ -Parameters @{ scan_run_id = $ScanRunId })

    if ($rows.Count -eq 0) {
        Write-Verbose "No results found for ScanRunId: $ScanRunId"
        return @()
    }

    $results = @(foreach ($row in $rows) {
        $check = @(Get-CIEMCheck -CheckId $row.check_id)
        if ($check.Count -eq 0) {
            throw "Scan result references unknown catalog check '$($row.check_id)'."
        }

        [PSCustomObject]@{
            Check = [PSCustomObject]@{
                Id          = $check[0].Id
                Provider    = $check[0].Provider
                Service     = $check[0].Service
                Title       = $check[0].Title
                Description = $check[0].Description
                Risk        = $check[0].Risk
                Severity    = $check[0].Severity
                Remediation = [PSCustomObject]@{
                    Text = $check[0].Remediation.Text
                    Url  = $check[0].Remediation.Url
                }
                RelatedUrl      = $check[0].RelatedUrl
                CheckScript     = $check[0].CheckScript
                ExecutionMode   = $check[0].ExecutionMode
                ManualReason    = $check[0].ManualReason
                Evaluator       = $check[0].Evaluator
                EvaluatorConfig = $check[0].EvaluatorConfig
                DependsOn       = @($check[0].DependsOn)
                DataNeeds       = if ($null -ne $check[0].DataNeeds) { @($check[0].DataNeeds) } else { $null }
                Disabled        = [bool]$check[0].Disabled
                Permissions     = $check[0].Permissions
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
