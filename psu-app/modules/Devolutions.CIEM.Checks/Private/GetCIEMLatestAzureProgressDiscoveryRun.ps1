function GetCIEMLatestAzureProgressDiscoveryRun {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$Connection
    )

    $ErrorActionPreference = 'Stop'

    $query = @"
SELECT
    id,
    completed_at,
    attack_path_scope_hash,
    discovery_scope_hash
FROM azure_discovery_runs
WHERE status = 'Completed'
AND scope = 'All'
AND completed_at IS NOT NULL
AND TRIM(completed_at) <> ''
AND attack_path_scope_hash IS NOT NULL
AND TRIM(attack_path_scope_hash) <> ''
AND discovery_scope_hash IS NOT NULL
AND TRIM(discovery_scope_hash) <> ''
AND exposure_snapshot_completed_at IS NOT NULL
AND TRIM(exposure_snapshot_completed_at) <> ''
ORDER BY julianday(completed_at) DESC, id DESC
LIMIT 1
"@

    if ($Connection) {
        Invoke-PSUSQLiteQuery -Connection $Connection -Query $query
    }
    else {
        Invoke-CIEMQuery -Query $query
    }
}
