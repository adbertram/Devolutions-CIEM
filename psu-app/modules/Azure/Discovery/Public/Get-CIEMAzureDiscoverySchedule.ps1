function Get-CIEMAzureDiscoverySchedule {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $ErrorActionPreference = 'Stop'

    $rows = @(Invoke-CIEMQuery -Query @"
SELECT provider_id, scope, cron, enabled, psu_schedule_id, psu_schedule_name,
       psu_script_name, last_status, last_discovery_run_id, last_psu_job_id,
       last_checked_at, created_at, updated_at
FROM azure_discovery_schedules
ORDER BY provider_id
"@)

    @(foreach ($row in $rows) {
        [PSCustomObject]@{
            ProviderId         = [string]$row.provider_id
            Scope              = [string]$row.scope
            Cron               = [string]$row.cron
            Enabled            = ([int]$row.enabled) -eq 1
            PsuScheduleId      = if ($null -eq $row.psu_schedule_id) { $null } else { [int]$row.psu_schedule_id }
            PsuScheduleName    = [string]$row.psu_schedule_name
            PsuScriptName      = [string]$row.psu_script_name
            LastStatus         = [string]$row.last_status
            LastDiscoveryRunId = if ($null -eq $row.last_discovery_run_id) { $null } else { [int]$row.last_discovery_run_id }
            LastPsuJobId       = if ($null -eq $row.last_psu_job_id) { $null } else { [int]$row.last_psu_job_id }
            LastCheckedAt      = [string]$row.last_checked_at
            CreatedAt          = [string]$row.created_at
            UpdatedAt          = [string]$row.updated_at
        }
    })
}
