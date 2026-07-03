function UpdateCIEMAttackPathStorageSchema {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $ruleColumns = @{}
    foreach ($column in @(Invoke-CIEMQuery -Query "PRAGMA table_info('attack_path_rules')")) {
        $ruleColumns[[string]$column.name] = [string]$column.type
    }
    if ($ruleColumns.Count -eq 0) {
        throw "Cannot migrate attack path rule storage because table 'attack_path_rules' does not exist."
    }

    foreach ($column in @(
        @{ Name = 'remediation';              Definition = 'TEXT' },
        @{ Name = 'remediation_script_path';  Definition = 'TEXT' },
        @{ Name = 'psu_script_name';          Definition = 'TEXT' },
        @{ Name = 'disabled';                 Definition = 'INTEGER NOT NULL DEFAULT 0' }
    )) {
        if (-not $ruleColumns.ContainsKey($column.Name)) {
            Invoke-CIEMQuery -Query "ALTER TABLE attack_path_rules ADD COLUMN $($column.Name) $($column.Definition)" -AsNonQuery | Out-Null
        }
    }

    $ruleColumns = @{}
    foreach ($column in @(Invoke-CIEMQuery -Query "PRAGMA table_info('attack_path_rules')")) {
        $ruleColumns[[string]$column.name] = [string]$column.type
    }

    if ($ruleColumns.ContainsKey('enabled')) {
        Invoke-CIEMQuery -Query 'UPDATE attack_path_rules SET disabled = CASE WHEN enabled = 0 THEN 1 ELSE disabled END' -AsNonQuery | Out-Null
    }
    Invoke-CIEMQuery -Query "UPDATE attack_path_rules SET disabled = 1 WHERE psu_script_name IS NULL OR TRIM(psu_script_name) = ''" -AsNonQuery | Out-Null

    $pathColumns = @{}
    foreach ($column in @(Invoke-CIEMQuery -Query "PRAGMA table_info('attack_paths')")) {
        $pathColumns[[string]$column.name] = [string]$column.type
    }

    $requiredPathColumns = @(
        'id',
        'rule_id',
        'pattern_name',
        'severity',
        'category',
        'remediation',
        'psu_script_name',
        'path_json',
        'edges_json',
        'path_chain',
        'evaluated_at'
    )

    $recreateAttackPaths = $pathColumns.Count -eq 0 -or $pathColumns['id'] -ne 'TEXT'
    foreach ($columnName in $requiredPathColumns) {
        if (-not $pathColumns.ContainsKey($columnName)) {
            $recreateAttackPaths = $true
        }
    }

    if ($recreateAttackPaths) {
        Invoke-CIEMQuery -Query 'DROP TABLE IF EXISTS attack_paths' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query @'
CREATE TABLE attack_paths (
    id TEXT PRIMARY KEY,
    rule_id TEXT NOT NULL,
    pattern_name TEXT NOT NULL,
    severity TEXT NOT NULL,
    category TEXT NOT NULL,
    remediation TEXT,
    psu_script_name TEXT NOT NULL,
    path_json TEXT NOT NULL,
    edges_json TEXT NOT NULL,
    path_chain TEXT NOT NULL,
    evaluated_at TEXT NOT NULL,
    FOREIGN KEY (rule_id) REFERENCES attack_path_rules(id) ON DELETE CASCADE
)
'@ -AsNonQuery | Out-Null
    }

    foreach ($tableName in @('attack_path_rules', 'attack_paths')) {
        Invoke-CIEMQuery -Query "UPDATE $tableName SET psu_script_name = REPLACE(psu_script_name, 'Identities/AttackPaths/AttackPathRemediation-', '') WHERE psu_script_name LIKE 'Identities/AttackPaths/AttackPathRemediation-%'" -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query "UPDATE $tableName SET psu_script_name = REPLACE(psu_script_name, 'Checks/AttackPathRemediation-', '') WHERE psu_script_name LIKE 'Checks/AttackPathRemediation-%'" -AsNonQuery | Out-Null
    }

    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_attack_path_rules_disabled ON attack_path_rules(disabled)' -AsNonQuery | Out-Null
    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_attack_paths_rule ON attack_paths(rule_id)' -AsNonQuery | Out-Null
    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_attack_paths_evaluated_at ON attack_paths(evaluated_at)' -AsNonQuery | Out-Null

    $snapshotColumns = @{}
    foreach ($column in @(Invoke-CIEMQuery -Query "PRAGMA table_info('ciem_exposure_snapshot_items')")) {
        $snapshotColumns[[string]$column.name] = [string]$column.type
    }
    if ($snapshotColumns.Count -gt 0 -and -not $snapshotColumns.ContainsKey('progress_key')) {
        Invoke-CIEMQuery -Query 'ALTER TABLE ciem_exposure_snapshot_items ADD COLUMN progress_key TEXT' -AsNonQuery | Out-Null
    }
    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_ciem_exposure_snapshot_progress_key ON ciem_exposure_snapshot_items(progress_key)' -AsNonQuery | Out-Null

    $discoveryColumns = @{}
    foreach ($column in @(Invoke-CIEMQuery -Query "PRAGMA table_info('azure_discovery_runs')")) {
        $discoveryColumns[[string]$column.name] = [string]$column.type
    }
    if ($discoveryColumns.Count -gt 0) {
        foreach ($column in @(
            @{ Name = 'attack_path_scope_hash';           Definition = 'TEXT' },
            @{ Name = 'discovery_scope_hash';              Definition = 'TEXT' },
            @{ Name = 'exposure_snapshot_completed_at';    Definition = 'TEXT' }
        )) {
            if (-not $discoveryColumns.ContainsKey($column.Name)) {
                Invoke-CIEMQuery -Query "ALTER TABLE azure_discovery_runs ADD COLUMN $($column.Name) $($column.Definition)" -AsNonQuery | Out-Null
            }
        }
    }
    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_discovery_runs_attack_path_scope ON azure_discovery_runs(attack_path_scope_hash)' -AsNonQuery | Out-Null
    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_discovery_runs_scope_hash ON azure_discovery_runs(discovery_scope_hash)' -AsNonQuery | Out-Null
}
