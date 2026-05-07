function Update-CIEMAzureDiscoveryScheduleStatus {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates local status metadata for the configured PSU schedule')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [int]$PsuScheduleId,

        [Parameter(Mandatory)]
        [ValidateSet('Running', 'Completed', 'Partial', 'Failed', 'Cancelled')]
        [string]$LastStatus,

        [Parameter(Mandatory)]
        [int]$LastDiscoveryRunId,

        [Parameter(Mandatory)]
        [int]$LastPsuJobId
    )

    $ErrorActionPreference = 'Stop'

    $now = (Get-Date).ToString('o')
    $affectedRows = Invoke-CIEMQuery -Query @"
UPDATE azure_discovery_schedules
SET last_status = @last_status,
    last_discovery_run_id = @last_discovery_run_id,
    last_psu_job_id = @last_psu_job_id,
    last_checked_at = @last_checked_at,
    updated_at = @updated_at
WHERE psu_schedule_id = @psu_schedule_id
"@ -Parameters @{
        psu_schedule_id       = $PsuScheduleId
        last_status           = $LastStatus
        last_discovery_run_id = $LastDiscoveryRunId
        last_psu_job_id       = $LastPsuJobId
        last_checked_at       = $now
        updated_at            = $now
    } -AsNonQuery

    if ([int]$affectedRows -ne 1) {
        throw "CIEM Azure discovery schedule with PSU schedule id '$PsuScheduleId' was not found."
    }

    Get-CIEMAzureDiscoverySchedule | Where-Object { $_.PsuScheduleId -eq $PsuScheduleId }
}
