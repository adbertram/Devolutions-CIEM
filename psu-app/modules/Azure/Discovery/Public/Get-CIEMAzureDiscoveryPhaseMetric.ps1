function Get-CIEMAzureDiscoveryPhaseMetric {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [int]$DiscoveryRunId,

        [Parameter()]
        [string]$PhaseName
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @()
    $parameters = @{}

    if ($PSBoundParameters.ContainsKey('DiscoveryRunId')) {
        $conditions += 'discovery_run_id = @discovery_run_id'
        $parameters.discovery_run_id = $DiscoveryRunId
    }
    if ($PSBoundParameters.ContainsKey('PhaseName')) {
        $conditions += 'phase_name = @phase_name'
        $parameters.phase_name = $PhaseName
    }

    $query = @"
SELECT id, discovery_run_id, phase_name, succeeded, elapsed_seconds, evidence, recorded_at
FROM azure_discovery_phase_metrics
"@

    if ($conditions.Count -gt 0) {
        $query += "`nWHERE " + ($conditions -join ' AND ')
    }

    $query += "`nORDER BY discovery_run_id DESC, id ASC"

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        [PSCustomObject]@{
            Id             = [int]$row.id
            DiscoveryRunId = [int]$row.discovery_run_id
            PhaseName      = [string]$row.phase_name
            Succeeded      = [bool]$row.succeeded
            ElapsedSeconds = [double]$row.elapsed_seconds
            Evidence       = [string]$row.evidence
            RecordedAt     = [string]$row.recorded_at
        }
    })
}
