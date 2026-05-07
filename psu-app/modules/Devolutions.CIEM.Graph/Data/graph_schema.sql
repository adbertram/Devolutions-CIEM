-- Graph Schema for Attack Path Discovery
-- Applied by module init alongside discovery_schema.sql
-- Tables: graph_nodes, graph_edges, attack_path_rules, attack_paths

-- =============================================================================
-- Graph Nodes (unified entity table replacing azure_arm_resources + azure_entra_resources)
-- =============================================================================

CREATE TABLE IF NOT EXISTS graph_nodes (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    display_name TEXT,
    provider TEXT NOT NULL DEFAULT 'azure',
    subscription_id TEXT,
    resource_group TEXT,
    properties TEXT,
    collected_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_graph_nodes_kind ON graph_nodes(kind);
CREATE INDEX IF NOT EXISTS idx_graph_nodes_provider ON graph_nodes(provider);
CREATE INDEX IF NOT EXISTS idx_graph_nodes_subscription ON graph_nodes(subscription_id);
CREATE INDEX IF NOT EXISTS idx_graph_nodes_display_name ON graph_nodes(display_name);

-- =============================================================================
-- Graph Edges (unified relationship table replacing azure_resource_relationships +
--              azure_effective_role_assignments + computed topology edges)
-- =============================================================================

CREATE TABLE IF NOT EXISTS graph_edges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    properties TEXT,
    computed INTEGER NOT NULL DEFAULT 0,
    collected_at TEXT NOT NULL,
    UNIQUE (source_id, target_id, kind),
    FOREIGN KEY (source_id) REFERENCES graph_nodes(id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES graph_nodes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_graph_edges_source ON graph_edges(source_id);
CREATE INDEX IF NOT EXISTS idx_graph_edges_target ON graph_edges(target_id);
CREATE INDEX IF NOT EXISTS idx_graph_edges_kind ON graph_edges(kind);
CREATE INDEX IF NOT EXISTS idx_graph_edges_source_kind ON graph_edges(source_id, kind);
CREATE INDEX IF NOT EXISTS idx_graph_edges_target_kind ON graph_edges(target_id, kind);
CREATE INDEX IF NOT EXISTS idx_graph_edges_computed ON graph_edges(computed);

-- =============================================================================
-- Attack Path Rules (global pattern catalog with PSU automation script references)
-- =============================================================================

CREATE TABLE IF NOT EXISTS attack_path_rules (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    severity TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    remediation TEXT,
    remediation_script_path TEXT,
    psu_script_name TEXT NOT NULL,
    steps_json TEXT NOT NULL,
    disabled INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_attack_path_rules_severity ON attack_path_rules(severity);
CREATE INDEX IF NOT EXISTS idx_attack_path_rules_category ON attack_path_rules(category);

-- =============================================================================
-- Attack Paths (materialized attack path findings from the current graph)
-- =============================================================================

CREATE TABLE IF NOT EXISTS attack_paths (
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
);

CREATE INDEX IF NOT EXISTS idx_attack_paths_severity ON attack_paths(severity);

-- =============================================================================
-- Exposure Snapshots And Changes (local alert-ready signal candidates)
-- =============================================================================

CREATE TABLE IF NOT EXISTS ciem_exposure_snapshot_items (
    discovery_run_id INTEGER NOT NULL,
    exposure_key TEXT NOT NULL,
    exposure_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    severity_rank INTEGER NOT NULL,
    impacted_identity_id TEXT,
    impacted_identity_name TEXT,
    impacted_identity_type TEXT,
    impacted_resource_id TEXT,
    impacted_resource_name TEXT,
    title TEXT NOT NULL,
    state_json TEXT NOT NULL,
    evidence TEXT NOT NULL,
    observed_at TEXT NOT NULL,
    PRIMARY KEY (discovery_run_id, exposure_key),
    FOREIGN KEY (discovery_run_id) REFERENCES azure_discovery_runs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ciem_exposure_snapshot_run ON ciem_exposure_snapshot_items(discovery_run_id);
CREATE INDEX IF NOT EXISTS idx_ciem_exposure_snapshot_key ON ciem_exposure_snapshot_items(exposure_key);
CREATE INDEX IF NOT EXISTS idx_ciem_exposure_snapshot_severity ON ciem_exposure_snapshot_items(severity_rank);

CREATE TABLE IF NOT EXISTS ciem_exposure_changes (
    id TEXT PRIMARY KEY,
    previous_discovery_run_id INTEGER,
    current_discovery_run_id INTEGER NOT NULL,
    exposure_key TEXT NOT NULL,
    change_type TEXT NOT NULL,
    exposure_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    severity_rank INTEGER NOT NULL,
    title TEXT NOT NULL,
    previous_severity TEXT,
    current_severity TEXT,
    impacted_identity_id TEXT,
    impacted_identity_name TEXT,
    impacted_identity_type TEXT,
    impacted_resource_id TEXT,
    impacted_resource_name TEXT,
    first_seen_at TEXT NOT NULL,
    previous_state_json TEXT,
    current_state_json TEXT,
    evidence TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE (current_discovery_run_id, exposure_key, change_type),
    FOREIGN KEY (previous_discovery_run_id) REFERENCES azure_discovery_runs(id) ON DELETE CASCADE,
    FOREIGN KEY (current_discovery_run_id) REFERENCES azure_discovery_runs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ciem_exposure_changes_current_run ON ciem_exposure_changes(current_discovery_run_id);
CREATE INDEX IF NOT EXISTS idx_ciem_exposure_changes_type ON ciem_exposure_changes(change_type);
CREATE INDEX IF NOT EXISTS idx_ciem_exposure_changes_severity ON ciem_exposure_changes(severity_rank);
