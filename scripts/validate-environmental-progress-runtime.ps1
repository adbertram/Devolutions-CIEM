[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('local', 'azure')]
    [string]$Environment = 'local',

    [Parameter()]
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$adminManifest = Join-Path $repoRoot 'Devolutions.CIEM.Admin/Devolutions.CIEM.Admin.psd1'
$fixturePath = Join-Path $repoRoot 'psu-app/ui/e2e/fixtures/environmental-progress-tracked.json'

Import-Module $adminManifest

$fixtureJson = Get-Content -LiteralPath $fixturePath -Raw
$compressedFixtureJson = ($fixtureJson | ConvertFrom-Json) | ConvertTo-Json -Depth 100 -Compress
$encodedFixtureJson = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($compressedFixtureJson))

$runtimeScript = [scriptblock]::Create(@"
`$ErrorActionPreference = 'Stop'
`$fixtureJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedFixtureJson'))
`$fixture = `$fixtureJson | ConvertFrom-Json
`$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ciem-environmental-progress-" + [guid]::NewGuid().ToString('N') + '.db')
`$originalPath = Get-CIEMDatabasePath

function Assert-Identifier {
    param([Parameter(Mandatory)][string]`$Value)
    if (`$Value -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        throw "Invalid SQL identifier '`$Value'."
    }
}

function ConvertTo-SqlValue {
    param([object]`$Value)
    if (`$null -eq `$Value) { return `$null }
    `$valueType = `$Value.GetType().FullName
    if (`$valueType -eq 'System.Management.Automation.PSCustomObject' -or `$Value -is [array]) {
        throw "Fixture values must be scalar."
    }
    `$Value
}

try {
    Use-CIEMTemporaryDatabase -Path `$tempPath -ScriptBlock {
        New-CIEMDatabase -Path `$tempPath | Out-Null
        `$connection = Open-PSUSQLiteConnection -Database `$tempPath
        try {
            Invoke-PSUSQLiteQuery -Connection `$connection -Query 'PRAGMA foreign_keys=ON' -AsNonQuery | Out-Null

            foreach (`$table in @(`$fixture.touchedTables)) {
                Assert-Identifier -Value ([string]`$table)
                Invoke-PSUSQLiteQuery -Connection `$connection -Query "DELETE FROM `$table" -AsNonQuery | Out-Null
            }

            `$insertOrder = @(`$fixture.touchedTables)
            [array]::Reverse(`$insertOrder)
            foreach (`$table in `$insertOrder) {
                Assert-Identifier -Value ([string]`$table)
                `$rows = @(`$fixture.tables.([string]`$table))
                foreach (`$row in `$rows) {
                    `$columns = @(`$row.PSObject.Properties.Name)
                    foreach (`$column in `$columns) {
                        Assert-Identifier -Value ([string]`$column)
                    }
                    `$parameters = @{}
                    foreach (`$column in `$columns) {
                        `$parameters[`$column] = ConvertTo-SqlValue -Value `$row.`$column
                    }
                    `$columnList = `$columns -join ', '
                    `$parameterList = @(foreach (`$column in `$columns) { "@`$column" }) -join ', '
                    Invoke-PSUSQLiteQuery -Connection `$connection -Query "INSERT INTO `$table (`$columnList) VALUES (`$parameterList)" -Parameters `$parameters -AsNonQuery | Out-Null
                }
            }

            foreach (`$table in @(`$fixture.touchedTables)) {
                `$row = Invoke-PSUSQLiteQuery -Connection `$connection -Query "SELECT COUNT(*) AS count FROM `$table"
                `$actual = [int]`$row.count
                `$expected = [int]`$fixture.expectedCounts.([string]`$table)
                if (`$actual -ne `$expected) {
                    throw "Fixture '`$(`$fixture.name)' expected `$expected rows in `$table, got `$actual."
                }
            }
        }
        finally {
            if (`$connection) { `$connection.Dispose() }
        }

        `$defaultResult = Devolutions.CIEM\Invoke-CIEMReport -Id 'azure.environmental.progress'
        if (`$defaultResult.Context.Status -ne 'ProgressTracked') {
            throw "Expected ProgressTracked status, got '`$(`$defaultResult.Context.Status)'."
        }
        if (@(`$defaultResult.Rows).Count -eq 0) {
            throw 'Expected environmental progress rows.'
        }
        if ([int]`$defaultResult.Context.FixedAttackPathCount -ne 1) {
            throw "Expected one fixed attack path, got `$(`$defaultResult.Context.FixedAttackPathCount)."
        }
        if ([int]`$defaultResult.Context.FixedCheckCount -ne 1) {
            throw "Expected one fixed check, got `$(`$defaultResult.Context.FixedCheckCount)."
        }
        if ([string]::IsNullOrWhiteSpace([string]`$defaultResult.Context.EvidencePairId) -and [string]::IsNullOrWhiteSpace([string]`$defaultResult.EvidencePairId)) {
            # CIEMReportResult does not have a top-level EvidencePairId; context provenance is authoritative.
        }

        `$pairId = 'baselineDiscovery:{0}|baselineScan:{1}|currentDiscovery:{2}|currentScan:{3}' -f @(
            `$defaultResult.Context.BaselineDiscoveryRunId,
            `$defaultResult.Context.BaselineScanRunId,
            `$defaultResult.Context.CurrentDiscoveryRunId,
            `$defaultResult.Context.CurrentScanRunId
        )
        `$explicitResult = Devolutions.CIEM\Invoke-CIEMReport -Id 'azure.environmental.progress' -Parameter @{ EvidencePairId = `$pairId }
        `$explicitPairId = 'baselineDiscovery:{0}|baselineScan:{1}|currentDiscovery:{2}|currentScan:{3}' -f @(
            `$explicitResult.Context.BaselineDiscoveryRunId,
            `$explicitResult.Context.BaselineScanRunId,
            `$explicitResult.Context.CurrentDiscoveryRunId,
            `$explicitResult.Context.CurrentScanRunId
        )
        if (`$explicitPairId -ne `$pairId) {
            throw "Explicit EvidencePairId returned '`$explicitPairId' instead of '`$pairId'."
        }

        [pscustomobject]@{
            OriginalDatabasePath = `$originalPath
            TemporaryDatabasePath = `$tempPath
            Status = `$defaultResult.Context.Status
            RowCount = @(`$defaultResult.Rows).Count
            EvidencePairId = `$pairId
            FixedAttackPathCount = `$defaultResult.Context.FixedAttackPathCount
            FixedCheckCount = `$defaultResult.Context.FixedCheckCount
        }
    }
}
finally {
    foreach (`$path in @(`$tempPath, "`$tempPath-wal", "`$tempPath-shm")) {
        if (Test-Path -LiteralPath `$path) {
            Remove-Item -LiteralPath `$path -Force
        }
    }
}
"@)

$result = Invoke-TestCommand -Environment $Environment -TimeoutSeconds $TimeoutSeconds -ScriptBlock $runtimeScript
if ($result.Status -notin @('Completed', 'Warning', 'WarningOutput')) {
    $errors = @($result.Output) |
        Where-Object { $_.type -eq 4 -and -not [string]::IsNullOrWhiteSpace([string]$_.message) } |
        ForEach-Object { [string]$_.message }
    $errorText = if ($errors.Count -gt 0) { $errors -join '; ' } else { 'No PSU error output was returned.' }
    throw "Environmental progress runtime validation failed with PSU job status '$($result.Status)': $errorText"
}

$result
