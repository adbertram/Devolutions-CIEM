function Set-CIEMAzureDiscoverySchedule {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates or removes the single CIEM-owned PSU discovery schedule')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet('All', 'ARM', 'Entra')]
        [string]$Scope = 'All',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Cron,

        [Parameter()]
        [bool]$Enabled = $true,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name = 'CIEM Azure Discovery'
    )

    $ErrorActionPreference = 'Stop'

    $cronFields = @($Cron -split '\s+' | Where-Object { $_ })
    if ($cronFields.Count -ne 5) {
        throw 'Cron must contain exactly 5 fields.'
    }
    if (@('0 2 * * *', '0 2 * * 1') -notcontains $Cron) {
        throw "Unsupported scheduled discovery cron '$Cron'. Supported values are '0 2 * * *' and '0 2 * * 1'."
    }

    $providerId = 'azure'
    $scriptName = 'Devolutions.CIEM\Start-CIEMAzureDiscovery'
    $managedDescription = 'ManagedBy=Devolutions.CIEM;Purpose=AzureDiscoverySchedule'
    $psuScheduleId = $null
    $existingSchedule = $null

    $existingSchedules = @(Get-PSUSchedule -Integrated | Where-Object { [string]$_.Name -eq $Name })
    if ($existingSchedules.Count -gt 1) {
        throw "Expected at most one PSU schedule named '$Name', found $($existingSchedules.Count)."
    }

    if ($existingSchedules.Count -eq 1) {
        $existingSchedule = $existingSchedules[0]
        if ([string]$existingSchedule.Description -ne $managedDescription) {
            throw "PSU schedule '$Name' already exists and is not managed by Devolutions.CIEM."
        }
    }

    if ($Enabled) {
        $scripts = @(Get-PSUScript -Integrated | Where-Object { [string]$_.Name -eq $scriptName })
        if ($scripts.Count -ne 1) {
            throw "Set-CIEMAzureDiscoverySchedule expected one $scriptName PSU script; found $($scripts.Count)."
        }

        $schedule = New-PSUSchedule `
            -Name $Name `
            -Script $scripts[0] `
            -Cron $Cron `
            -Parameters @{ Scope = $Scope } `
            -Description $managedDescription `
            -Integrated `
            -WarningAction SilentlyContinue

        if ($null -eq $schedule.Id) {
            throw "New-PSUSchedule did not return an Id for '$Name'."
        }

        $psuScheduleId = [int]$schedule.Id

        if ($existingSchedule) {
            Remove-PSUSchedule -Schedule $existingSchedule -Integrated -WarningAction SilentlyContinue | Out-Null
        }
    }
    elseif ($existingSchedule) {
        Remove-PSUSchedule -Schedule $existingSchedule -Integrated -WarningAction SilentlyContinue | Out-Null
    }

    $now = (Get-Date).ToString('o')
    Invoke-CIEMQuery -Query @"
INSERT INTO azure_discovery_schedules (
    provider_id, scope, cron, enabled, psu_schedule_id, psu_schedule_name,
    psu_script_name, created_at, updated_at
)
VALUES (
    @provider_id, @scope, @cron, @enabled, @psu_schedule_id, @psu_schedule_name,
    @psu_script_name, @created_at, @updated_at
)
ON CONFLICT(provider_id) DO UPDATE SET
    scope = excluded.scope,
    cron = excluded.cron,
    enabled = excluded.enabled,
    psu_schedule_id = excluded.psu_schedule_id,
    psu_schedule_name = excluded.psu_schedule_name,
    psu_script_name = excluded.psu_script_name,
    updated_at = excluded.updated_at
"@ -Parameters @{
        provider_id       = $providerId
        scope             = $Scope
        cron              = $Cron
        enabled           = if ($Enabled) { 1 } else { 0 }
        psu_schedule_id   = $psuScheduleId
        psu_schedule_name = $Name
        psu_script_name   = $scriptName
        created_at        = $now
        updated_at        = $now
    } -AsNonQuery | Out-Null

    Get-CIEMAzureDiscoverySchedule | Where-Object { $_.ProviderId -eq $providerId }
}
