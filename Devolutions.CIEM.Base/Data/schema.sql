-- CIEM Database Schema
-- SQLite with WAL mode for concurrent read support
-- All tables use IF NOT EXISTS for idempotent creation

PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

-- =============================================================================
-- Generic Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS providers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    is_default INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- =============================================================================
-- Azure Infrastructure Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_authentication_profiles (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    name TEXT NOT NULL,
    method TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    tenant_id TEXT NOT NULL,
    client_id TEXT,
    managed_identity_client_id TEXT,
    secret_name TEXT,
    secret_type TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE (provider_id, name),
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_auth_profiles_provider ON azure_authentication_profiles(provider_id);

CREATE TABLE IF NOT EXISTS azure_provider_apis (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    base_url TEXT NOT NULL,
    version TEXT
);

CREATE TABLE IF NOT EXISTS azure_scopes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider_api_id INTEGER NOT NULL,
    scope TEXT NOT NULL,
    resource_type_id TEXT,
    UNIQUE (provider_api_id, scope),
    FOREIGN KEY (provider_api_id) REFERENCES azure_provider_apis(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_scopes_api ON azure_scopes(provider_api_id);
CREATE INDEX IF NOT EXISTS idx_azure_scopes_resource_type ON azure_scopes(resource_type_id);

CREATE TABLE IF NOT EXISTS azure_resource_types (
    id TEXT PRIMARY KEY,
    provider_api_id INTEGER NOT NULL,
    display_name TEXT NOT NULL,
    is_collectible INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (provider_api_id) REFERENCES azure_provider_apis(id)
);

CREATE INDEX IF NOT EXISTS idx_azure_resource_types_api ON azure_resource_types(provider_api_id);

-- =============================================================================
-- Azure Identity Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_security_principals (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    type TEXT NOT NULL,
    display_name TEXT NOT NULL,
    enabled INTEGER,
    category TEXT NOT NULL,
    principal_type TEXT,
    user_principal_name TEXT,
    user_type TEXT,
    app_id TEXT,
    service_principal_type TEXT,
    collected_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_principals_provider ON azure_security_principals(provider_id);
CREATE INDEX IF NOT EXISTS idx_azure_principals_type ON azure_security_principals(type);
CREATE INDEX IF NOT EXISTS idx_azure_principals_category ON azure_security_principals(category);
CREATE INDEX IF NOT EXISTS idx_azure_principals_upn ON azure_security_principals(user_principal_name);
CREATE INDEX IF NOT EXISTS idx_azure_principals_app_id ON azure_security_principals(app_id);

CREATE TABLE IF NOT EXISTS azure_group_memberships (
    group_id TEXT NOT NULL,
    member_id TEXT NOT NULL,
    member_type TEXT NOT NULL,
    PRIMARY KEY (group_id, member_id),
    FOREIGN KEY (group_id) REFERENCES azure_security_principals(id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES azure_security_principals(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_group_members_member ON azure_group_memberships(member_id);
CREATE INDEX IF NOT EXISTS idx_azure_group_members_type ON azure_group_memberships(member_type);

-- =============================================================================
-- Azure Resource Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_resources (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    type TEXT NOT NULL,
    parent_id TEXT,
    name TEXT NOT NULL,
    location TEXT,
    tags TEXT,
    collected_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_resources_provider ON azure_resources(provider_id);
CREATE INDEX IF NOT EXISTS idx_azure_resources_type ON azure_resources(type);
CREATE INDEX IF NOT EXISTS idx_azure_resources_parent ON azure_resources(parent_id);

CREATE TABLE IF NOT EXISTS azure_resource_relationships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    relationship_type TEXT NOT NULL,
    properties TEXT,
    collected_at TEXT NOT NULL,
    UNIQUE (source_id, target_id, relationship_type)
);

CREATE INDEX IF NOT EXISTS idx_azure_res_rel_source ON azure_resource_relationships(source_id);
CREATE INDEX IF NOT EXISTS idx_azure_res_rel_target ON azure_resource_relationships(target_id);
CREATE INDEX IF NOT EXISTS idx_azure_res_rel_type ON azure_resource_relationships(relationship_type);

CREATE TABLE IF NOT EXISTS azure_resource_properties (
    resource_id TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT,
    PRIMARY KEY (resource_id, key)
);

CREATE INDEX IF NOT EXISTS idx_azure_res_props_key ON azure_resource_properties(key);
CREATE INDEX IF NOT EXISTS idx_azure_res_props_key_value ON azure_resource_properties(key, value);

-- =============================================================================
-- Azure Permission Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_role_definitions (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    role_name TEXT NOT NULL,
    role_type TEXT NOT NULL,
    description TEXT,
    assignable_scopes TEXT,
    collected_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_role_defs_provider ON azure_role_definitions(provider_id);
CREATE INDEX IF NOT EXISTS idx_azure_role_defs_name ON azure_role_definitions(role_name);
CREATE INDEX IF NOT EXISTS idx_azure_role_defs_type ON azure_role_definitions(role_type);

CREATE TABLE IF NOT EXISTS azure_role_definition_permissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    role_definition_id TEXT NOT NULL,
    action_type TEXT NOT NULL,
    action TEXT NOT NULL,
    UNIQUE (role_definition_id, action_type, action),
    FOREIGN KEY (role_definition_id) REFERENCES azure_role_definitions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_role_perms_def ON azure_role_definition_permissions(role_definition_id);
CREATE INDEX IF NOT EXISTS idx_azure_role_perms_action_type ON azure_role_definition_permissions(action_type);
CREATE INDEX IF NOT EXISTS idx_azure_role_perms_action ON azure_role_definition_permissions(action);

CREATE TABLE IF NOT EXISTS azure_role_assignments (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    principal_id TEXT NOT NULL,
    principal_type TEXT NOT NULL,
    role_definition_id TEXT NOT NULL,
    scope TEXT NOT NULL,
    condition TEXT,
    condition_version TEXT,
    description TEXT,
    created_on TEXT,
    collected_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_role_assign_provider ON azure_role_assignments(provider_id);
CREATE INDEX IF NOT EXISTS idx_azure_role_assign_principal ON azure_role_assignments(principal_id);
CREATE INDEX IF NOT EXISTS idx_azure_role_assign_role_def ON azure_role_assignments(role_definition_id);
CREATE INDEX IF NOT EXISTS idx_azure_role_assign_scope ON azure_role_assignments(scope);
CREATE INDEX IF NOT EXISTS idx_azure_role_assign_principal_type ON azure_role_assignments(principal_type);

CREATE TABLE IF NOT EXISTS azure_deny_assignments (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    deny_assignment_name TEXT NOT NULL,
    description TEXT,
    scope TEXT NOT NULL,
    do_not_apply_to_children INTEGER NOT NULL DEFAULT 0,
    principals TEXT NOT NULL,
    exclude_principals TEXT,
    permissions_actions TEXT,
    permissions_not_actions TEXT,
    permissions_data_actions TEXT,
    permissions_not_data_actions TEXT,
    condition TEXT,
    is_system_protected INTEGER NOT NULL DEFAULT 1,
    collected_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_deny_assign_provider ON azure_deny_assignments(provider_id);
CREATE INDEX IF NOT EXISTS idx_azure_deny_assign_scope ON azure_deny_assignments(scope);

CREATE TABLE IF NOT EXISTS azure_directory_role_assignments (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    principal_id TEXT NOT NULL,
    role_name TEXT NOT NULL,
    role_template_id TEXT,
    collected_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_dir_role_assign_provider ON azure_directory_role_assignments(provider_id);
CREATE INDEX IF NOT EXISTS idx_azure_dir_role_assign_principal ON azure_directory_role_assignments(principal_id);
CREATE INDEX IF NOT EXISTS idx_azure_dir_role_assign_role ON azure_directory_role_assignments(role_name);

CREATE TABLE IF NOT EXISTS azure_app_role_assignments (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    principal_id TEXT NOT NULL,
    principal_type TEXT NOT NULL,
    resource_id TEXT,
    resource_display_name TEXT,
    app_role_id TEXT NOT NULL,
    app_role_value TEXT,
    collected_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_app_role_assign_provider ON azure_app_role_assignments(provider_id);
CREATE INDEX IF NOT EXISTS idx_azure_app_role_assign_principal ON azure_app_role_assignments(principal_id);
CREATE INDEX IF NOT EXISTS idx_azure_app_role_assign_resource ON azure_app_role_assignments(resource_id);

-- =============================================================================
-- Checks Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS checks (
    id TEXT PRIMARY KEY,
    provider TEXT NOT NULL,
    service TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    risk TEXT,
    severity TEXT NOT NULL,
    remediation_text TEXT,
    remediation_url TEXT,
    related_url TEXT,
    check_script TEXT NOT NULL,
    disabled INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_checks_provider ON checks(provider);
CREATE INDEX IF NOT EXISTS idx_checks_service ON checks(service);
CREATE INDEX IF NOT EXISTS idx_checks_severity ON checks(severity);

CREATE TABLE IF NOT EXISTS scan_runs (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    status TEXT NOT NULL,
    resource_filter TEXT,
    resource_providers TEXT,
    include_passed INTEGER DEFAULT 1,
    started_at TEXT NOT NULL,
    completed_at TEXT,
    duration_seconds REAL,
    total_results INTEGER DEFAULT 0,
    failed_results INTEGER DEFAULT 0,
    passed_results INTEGER DEFAULT 0,
    skipped_results INTEGER DEFAULT 0,
    manual_results INTEGER DEFAULT 0,
    error_message TEXT,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_scan_runs_provider ON scan_runs(provider_id);
CREATE INDEX IF NOT EXISTS idx_scan_runs_started ON scan_runs(started_at);

CREATE TABLE IF NOT EXISTS scan_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_run_id TEXT NOT NULL,
    check_id TEXT NOT NULL,
    status TEXT NOT NULL,
    status_extended TEXT,
    resource_id TEXT,
    resource_name TEXT,
    location TEXT,
    FOREIGN KEY (scan_run_id) REFERENCES scan_runs(id) ON DELETE CASCADE,
    FOREIGN KEY (check_id) REFERENCES checks(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_scan_results_run_status ON scan_results(scan_run_id, status);
CREATE INDEX IF NOT EXISTS idx_scan_results_check ON scan_results(check_id);
CREATE INDEX IF NOT EXISTS idx_scan_results_resource ON scan_results(resource_id);
