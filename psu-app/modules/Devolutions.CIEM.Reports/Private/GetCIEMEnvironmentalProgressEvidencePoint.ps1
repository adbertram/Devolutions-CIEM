function GetCIEMEnvironmentalProgressEvidencePoint {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProgressScopeHash,

        [Parameter()]
        [int]$DiscoveryRunId,

        [Parameter()]
        [string]$ScanRunId
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @()
    $parameters = @{}
    if ($PSBoundParameters.ContainsKey('ProgressScopeHash')) {
        $conditions += 'ranked.progress_scope_hash = @progress_scope_hash'
        $parameters.progress_scope_hash = $ProgressScopeHash
    }
    if ($PSBoundParameters.ContainsKey('DiscoveryRunId')) {
        $conditions += 'ranked.discovery_run_id = @discovery_run_id'
        $parameters.discovery_run_id = $DiscoveryRunId
    }
    if ($PSBoundParameters.ContainsKey('ScanRunId')) {
        if ([string]::IsNullOrWhiteSpace($ScanRunId)) {
            throw 'ScanRunId cannot be blank.'
        }
        $conditions += 'ranked.scan_run_id = @scan_run_id'
        $parameters.scan_run_id = $ScanRunId
    }

    $where = ''
    if ($conditions.Count -gt 0) {
        $where = "`nAND " + ($conditions -join ' AND ')
    }

    $rankPredicate = if ($PSBoundParameters.ContainsKey('DiscoveryRunId') -or $PSBoundParameters.ContainsKey('ScanRunId')) {
        '1 = 1'
    }
    else {
        'scan_rank = 1'
    }

    $query = @"
WITH eligible AS (
    SELECT
        d.id AS discovery_run_id,
        d.status AS discovery_status,
        d.scope AS discovery_scope,
        d.started_at AS discovery_started_at,
        d.completed_at AS discovery_completed_at,
        d.exposure_snapshot_completed_at AS exposure_snapshot_completed_at,
        s.id AS scan_run_id,
        s.status AS scan_status,
        s.started_at AS scan_started_at,
        s.completed_at AS scan_completed_at,
        s.progress_scope_hash AS progress_scope_hash,
        s.rowid AS scan_rowid
    FROM azure_discovery_runs d
    INNER JOIN scan_runs s ON s.discovery_run_id = d.id
    WHERE d.status = 'Completed'
    AND d.scope = 'All'
    AND d.completed_at IS NOT NULL
    AND TRIM(d.completed_at) <> ''
    AND d.attack_path_scope_hash IS NOT NULL
    AND TRIM(d.attack_path_scope_hash) <> ''
    AND d.discovery_scope_hash IS NOT NULL
    AND TRIM(d.discovery_scope_hash) <> ''
    AND d.exposure_snapshot_completed_at IS NOT NULL
    AND TRIM(d.exposure_snapshot_completed_at) <> ''
    AND s.status = 'Completed'
    AND s.completed_at IS NOT NULL
    AND TRIM(s.completed_at) <> ''
    AND s.progress_eligible = 1
    AND s.progress_scope_hash IS NOT NULL
    AND TRIM(s.progress_scope_hash) <> ''
    AND julianday(s.started_at) >= julianday(d.completed_at)
    AND EXISTS (
        SELECT 1
        FROM scan_run_providers srp
        WHERE srp.scan_run_id = s.id
        AND srp.provider = 'Azure'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM scan_run_providers other_srp
        WHERE other_srp.scan_run_id = s.id
        AND other_srp.provider <> 'Azure'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM azure_discovery_runs other_discovery
        WHERE other_discovery.id <> d.id
        AND other_discovery.started_at IS NOT NULL
        AND other_discovery.completed_at IS NOT NULL
        AND TRIM(other_discovery.started_at) <> ''
        AND TRIM(other_discovery.completed_at) <> ''
        AND julianday(s.started_at) < julianday(other_discovery.completed_at)
        AND julianday(s.completed_at) > julianday(other_discovery.started_at)
    )
    AND NOT EXISTS (
        SELECT 1
        FROM scan_runs other_scan
        INNER JOIN scan_run_providers other_scan_provider
            ON other_scan_provider.scan_run_id = other_scan.id
        WHERE other_scan.id <> s.id
        AND other_scan_provider.provider = 'Azure'
        AND other_scan.started_at IS NOT NULL
        AND other_scan.completed_at IS NOT NULL
        AND TRIM(other_scan.started_at) <> ''
        AND TRIM(other_scan.completed_at) <> ''
        AND julianday(other_scan.started_at) < julianday(d.completed_at)
        AND julianday(other_scan.completed_at) > julianday(d.started_at)
    )
),
ranked AS (
    SELECT
        eligible.*,
        ROW_NUMBER() OVER (
            PARTITION BY eligible.discovery_run_id
            ORDER BY julianday(eligible.scan_completed_at) DESC,
                     julianday(eligible.scan_started_at) DESC,
                     eligible.scan_rowid DESC
        ) AS scan_rank
    FROM eligible
)
SELECT
    discovery_run_id,
    discovery_status,
    discovery_scope,
    discovery_started_at,
    discovery_completed_at,
    exposure_snapshot_completed_at,
    scan_run_id,
    scan_status,
    scan_started_at,
    scan_completed_at,
    progress_scope_hash
FROM ranked
WHERE $rankPredicate$where
ORDER BY julianday(discovery_completed_at) DESC, julianday(scan_completed_at) DESC, discovery_run_id DESC
"@

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)
    foreach ($row in $rows) {
        [pscustomobject]@{
            DiscoveryRunId              = [int]$row.discovery_run_id
            DiscoveryStatus             = [string]$row.discovery_status
            DiscoveryScope              = [string]$row.discovery_scope
            DiscoveryStartedAt          = [string]$row.discovery_started_at
            DiscoveryCompletedAt        = [string]$row.discovery_completed_at
            ExposureSnapshotCompletedAt = [string]$row.exposure_snapshot_completed_at
            ScanRunId                   = [string]$row.scan_run_id
            ScanStatus                  = [string]$row.scan_status
            ScanStartedAt               = [string]$row.scan_started_at
            ScanCompletedAt             = [string]$row.scan_completed_at
            ProgressScopeHash           = [string]$row.progress_scope_hash
        }
    }
}
