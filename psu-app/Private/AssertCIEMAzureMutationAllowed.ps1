function AssertCIEMAzureMutationAllowed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Connection,

        [Parameter(Mandatory)]
        [ValidateSet('AzureScan', 'AzureDiscovery')]
        [string]$Starting
    )

    $ErrorActionPreference = 'Stop'

    Invoke-PSUSQLiteQuery -Connection $Connection -Query 'PRAGMA foreign_keys=ON' -AsNonQuery | Out-Null

    if ($Starting -eq 'AzureScan') {
        $runningDiscovery = @(Invoke-PSUSQLiteQuery -Connection $Connection -Query @'
SELECT id
FROM azure_discovery_runs
WHERE status = 'Running'
ORDER BY id
LIMIT 1
'@)
        if ($runningDiscovery.Count -gt 0) {
            throw "A CIEM Azure discovery run is already in progress (Id=$($runningDiscovery[0].id)). Wait for it to complete or clear stale runs."
        }
        return
    }

    $runningDiscovery = @(Invoke-PSUSQLiteQuery -Connection $Connection -Query @'
SELECT id
FROM azure_discovery_runs
WHERE status = 'Running'
ORDER BY id
LIMIT 1
'@)
    if ($runningDiscovery.Count -gt 0) {
        throw "A CIEM Azure discovery run is already in progress (Id=$($runningDiscovery[0].id)). Wait for it to complete or clear stale runs."
    }

    $runningScan = @(Invoke-PSUSQLiteQuery -Connection $Connection -Query @'
SELECT s.id
FROM scan_runs s
WHERE s.status = 'Running'
AND EXISTS (
    SELECT 1
    FROM scan_run_providers srp
    WHERE srp.scan_run_id = s.id
    AND srp.provider = 'Azure'
)
ORDER BY julianday(s.started_at), s.rowid
LIMIT 1
'@)
    if ($runningScan.Count -gt 0) {
        throw "A CIEM Azure scan is already in progress (Id=$($runningScan[0].id)). Wait for it to complete or clear stale runs."
    }
}
