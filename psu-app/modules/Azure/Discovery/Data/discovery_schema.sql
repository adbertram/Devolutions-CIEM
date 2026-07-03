-- Azure Discovery Schema
-- Applied by New-CIEMDatabase at module init time
-- Tables: azure_arm_resources, azure_entra_resources, azure_resource_types,
--         azure_discovery_runs, azure_resource_relationships

-- =============================================================================
-- Azure ARM Resources (from Azure Resource Graph)
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_arm_resources (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    location TEXT,
    resource_group TEXT,
    subscription_id TEXT,
    tenant_id TEXT,
    kind TEXT,
    sku TEXT,
    identity TEXT,
    managed_by TEXT,
    plan TEXT,
    zones TEXT,
    tags TEXT,
    properties TEXT,
    collected_at TEXT NOT NULL,
    last_seen_at INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_arm_resources_type ON azure_arm_resources(type);
CREATE INDEX IF NOT EXISTS idx_arm_resources_subscription ON azure_arm_resources(subscription_id);
CREATE INDEX IF NOT EXISTS idx_arm_resources_resource_group ON azure_arm_resources(resource_group);
CREATE INDEX IF NOT EXISTS idx_arm_resources_name ON azure_arm_resources(name);

-- =============================================================================
-- Azure Entra Resources (from Microsoft Graph API)
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_entra_resources (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    display_name TEXT,
    parent_id TEXT,
    properties TEXT,
    collected_at TEXT NOT NULL,
    last_seen_at INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_entra_resources_type ON azure_entra_resources(type);
CREATE INDEX IF NOT EXISTS idx_entra_resources_display_name ON azure_entra_resources(display_name);
CREATE INDEX IF NOT EXISTS idx_entra_resources_parent_id ON azure_entra_resources(parent_id);

-- =============================================================================
-- Azure Resource Types (auto-populated by discovery engine)
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_resource_types (
    type TEXT PRIMARY KEY,
    api_source TEXT NOT NULL,
    graph_table TEXT,
    resource_count INTEGER NOT NULL DEFAULT 0,
    discovered_at TEXT NOT NULL,
    last_collected TEXT
);

CREATE INDEX IF NOT EXISTS idx_resource_types_api_source ON azure_resource_types(api_source);

-- =============================================================================
-- Azure Discovery Runs
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_discovery_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    psu_job_id INTEGER,
    scope TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at TEXT NOT NULL,
    completed_at TEXT,
    arm_type_count INTEGER DEFAULT 0,
    arm_row_count INTEGER DEFAULT 0,
    entra_type_count INTEGER DEFAULT 0,
    entra_row_count INTEGER DEFAULT 0,
    warning_count INTEGER DEFAULT 0,
    error_message TEXT,
    attack_path_scope_hash TEXT,
    discovery_scope_hash TEXT,
    exposure_snapshot_completed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_discovery_runs_status ON azure_discovery_runs(status);
CREATE INDEX IF NOT EXISTS idx_discovery_runs_started ON azure_discovery_runs(started_at);

-- =============================================================================
-- Azure Discovery Schedules
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_discovery_schedules (
    provider_id TEXT PRIMARY KEY,
    scope TEXT NOT NULL,
    cron TEXT NOT NULL,
    enabled INTEGER NOT NULL,
    psu_schedule_id INTEGER,
    psu_schedule_name TEXT NOT NULL,
    psu_script_name TEXT NOT NULL,
    last_status TEXT,
    last_discovery_run_id INTEGER,
    last_psu_job_id INTEGER,
    last_checked_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id)
);

CREATE INDEX IF NOT EXISTS idx_azure_discovery_schedules_enabled ON azure_discovery_schedules(enabled);
CREATE INDEX IF NOT EXISTS idx_azure_discovery_schedules_psu_schedule ON azure_discovery_schedules(psu_schedule_id);

-- =============================================================================
-- Azure Discovery Phase Metrics
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_discovery_phase_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    discovery_run_id INTEGER NOT NULL,
    phase_name TEXT NOT NULL,
    succeeded INTEGER NOT NULL,
    elapsed_seconds REAL NOT NULL,
    evidence TEXT,
    recorded_at TEXT NOT NULL,
    UNIQUE (discovery_run_id, phase_name),
    FOREIGN KEY (discovery_run_id) REFERENCES azure_discovery_runs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_discovery_phase_metrics_run ON azure_discovery_phase_metrics(discovery_run_id);
CREATE INDEX IF NOT EXISTS idx_discovery_phase_metrics_phase ON azure_discovery_phase_metrics(phase_name);

-- =============================================================================
-- Azure Resource Relationships
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_resource_relationships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id TEXT NOT NULL,
    source_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    target_type TEXT NOT NULL,
    relationship TEXT NOT NULL,
    collected_at TEXT NOT NULL,
    UNIQUE (source_id, target_id, relationship)
);

CREATE INDEX IF NOT EXISTS idx_resource_rel_source ON azure_resource_relationships(source_id);
CREATE INDEX IF NOT EXISTS idx_resource_rel_target ON azure_resource_relationships(target_id);
CREATE INDEX IF NOT EXISTS idx_resource_rel_relationship ON azure_resource_relationships(relationship);

-- =============================================================================
-- Azure Effective Role Assignments (pre-resolved identity-to-resource mappings)
-- Scope is stored as-is from the role assignment (not expanded). Use prefix
-- matching at query time for scope inheritance (e.g., WHERE resource_id LIKE scope || '%').
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_effective_role_assignments (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    principal_id        TEXT NOT NULL,
    principal_type      TEXT NOT NULL,
    principal_display_name TEXT,
    original_principal_id TEXT NOT NULL,
    original_principal_type TEXT NOT NULL,
    role_definition_id  TEXT NOT NULL,
    role_name           TEXT,
    scope               TEXT NOT NULL,
    permissions_json    TEXT,
    computed_at         TEXT NOT NULL,
    UNIQUE (principal_id, role_definition_id, scope, original_principal_id)
);

CREATE INDEX IF NOT EXISTS idx_effective_ra_principal ON azure_effective_role_assignments(principal_id);
CREATE INDEX IF NOT EXISTS idx_effective_ra_scope ON azure_effective_role_assignments(scope);
CREATE INDEX IF NOT EXISTS idx_effective_ra_role_def ON azure_effective_role_assignments(role_definition_id);
CREATE INDEX IF NOT EXISTS idx_effective_ra_principal_type ON azure_effective_role_assignments(principal_type);

CREATE INDEX IF NOT EXISTS idx_arm_resources_last_seen ON azure_arm_resources(last_seen_at);
CREATE INDEX IF NOT EXISTS idx_entra_resources_last_seen ON azure_entra_resources(last_seen_at);
