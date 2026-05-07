function Save-CIEMAzureDiscoveryPhaseMetric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$DiscoveryRunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PhaseName,

        [Parameter(Mandatory)]
        [bool]$Succeeded,

        [Parameter(Mandatory)]
        [ValidateRange(0, [double]::MaxValue)]
        [double]$ElapsedSeconds,

        [Parameter()]
        [string]$Evidence,

        [Parameter()]
        [string]$RecordedAt = (Get-Date).ToString('o')
    )

    $ErrorActionPreference = 'Stop'

    $runRows = @(Invoke-CIEMQuery -Query 'SELECT id FROM azure_discovery_runs WHERE id = @id' -Parameters @{ id = $DiscoveryRunId })
    if ($runRows.Count -ne 1) {
        throw "Discovery run '$DiscoveryRunId' was not found."
    }

    Invoke-CIEMQuery -Query @"
INSERT OR REPLACE INTO azure_discovery_phase_metrics (
    discovery_run_id, phase_name, succeeded, elapsed_seconds, evidence, recorded_at
)
VALUES (
    @discovery_run_id, @phase_name, @succeeded, @elapsed_seconds, @evidence, @recorded_at
)
"@ -Parameters @{
        discovery_run_id = $DiscoveryRunId
        phase_name       = $PhaseName
        succeeded        = if ($Succeeded) { 1 } else { 0 }
        elapsed_seconds  = [math]::Round($ElapsedSeconds, 2, [MidpointRounding]::AwayFromZero)
        evidence         = $Evidence
        recorded_at      = $RecordedAt
    } -AsNonQuery | Out-Null

    @(Get-CIEMAzureDiscoveryPhaseMetric -DiscoveryRunId $DiscoveryRunId -PhaseName $PhaseName)[0]
}
