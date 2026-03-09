-- CIEM Database Schema (Generic Tables)
-- SQLite with WAL mode for concurrent read support
-- All tables use IF NOT EXISTS for idempotent creation
-- Azure-specific tables are in Azure/Infrastructure/Data/azure_schema.sql
-- All Azure service data (identity + infrastructure) is stored in azure_service_data (see azure_schema.sql)

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
    disabled INTEGER NOT NULL DEFAULT 0,
    permissions TEXT,
    depends_on TEXT
);

CREATE INDEX IF NOT EXISTS idx_checks_provider ON checks(provider);
CREATE INDEX IF NOT EXISTS idx_checks_service ON checks(service);
CREATE INDEX IF NOT EXISTS idx_checks_severity ON checks(severity);

CREATE TABLE IF NOT EXISTS scan_runs (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    scan_type TEXT NOT NULL DEFAULT 'checks',
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

-- =============================================================================
-- Reference Tables (static vocabulary, seeded at init, never written at runtime)
-- =============================================================================

-- Provider Authentication Methods (available auth methods per provider)
CREATE TABLE IF NOT EXISTS provider_auth_methods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider TEXT NOT NULL,
    method TEXT NOT NULL,
    display_name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    UNIQUE (provider, method)
);

CREATE INDEX IF NOT EXISTS idx_provider_auth_methods_provider ON provider_auth_methods(provider);

-- Identity Types (canonical identity principal type vocabulary per provider)
CREATE TABLE IF NOT EXISTS identity_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    type TEXT NOT NULL,
    provider TEXT NOT NULL,
    principal_type TEXT,
    graph_node_type TEXT NOT NULL,
    description TEXT,
    UNIQUE (name, provider)
);

CREATE INDEX IF NOT EXISTS idx_identity_types_provider ON identity_types(provider);
CREATE INDEX IF NOT EXISTS idx_identity_types_type ON identity_types(type);

-- Resource Types (canonical cloud resource type vocabulary per provider)
CREATE TABLE IF NOT EXISTS resource_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    provider TEXT NOT NULL,
    service_name TEXT,
    arm_provider_prefix TEXT,
    arn_service_prefix TEXT,
    UNIQUE (name, provider)
);

CREATE INDEX IF NOT EXISTS idx_resource_types_provider ON resource_types(provider);
CREATE INDEX IF NOT EXISTS idx_resource_types_service ON resource_types(service_name);

-- Permission Relationships (maps ARM permissions to CAN_READ/WRITE/MANAGE graph edges)
-- Normalized: one row per permission string (JSON array entries become individual rows)
CREATE TABLE IF NOT EXISTS permission_relationships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    target_type TEXT NOT NULL,
    permission TEXT NOT NULL,
    relationship TEXT NOT NULL,
    UNIQUE (target_type, permission, relationship)
);

CREATE INDEX IF NOT EXISTS idx_perm_rel_target ON permission_relationships(target_type);
CREATE INDEX IF NOT EXISTS idx_perm_rel_relationship ON permission_relationships(relationship);
CREATE INDEX IF NOT EXISTS idx_perm_rel_target_rel ON permission_relationships(target_type, relationship);

-- =============================================================================
-- Identity-Resource Access (computed junction: identity → resource instance)
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity_resource_access (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider_id TEXT NOT NULL,
    identity_id TEXT NOT NULL,
    identity_name TEXT,
    identity_type TEXT NOT NULL,
    resource_id TEXT NOT NULL,
    resource_name TEXT,
    resource_type TEXT NOT NULL,
    relationship TEXT NOT NULL,
    scope TEXT NOT NULL,
    is_inherited INTEGER NOT NULL DEFAULT 0,
    effective_identity_id TEXT,
    effective_identity_name TEXT,
    role_name TEXT,
    computed_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ira_provider ON identity_resource_access(provider_id);
CREATE INDEX IF NOT EXISTS idx_ira_identity ON identity_resource_access(identity_id);
CREATE INDEX IF NOT EXISTS idx_ira_resource ON identity_resource_access(resource_id);
CREATE INDEX IF NOT EXISTS idx_ira_relationship ON identity_resource_access(relationship);
CREATE INDEX IF NOT EXISTS idx_ira_identity_resource ON identity_resource_access(identity_id, resource_type, relationship);

-- =============================================================================
-- Migrations (ALTER TABLE — safe for re-runs via error handling in New-CIEMDatabase)
-- =============================================================================

ALTER TABLE scan_runs ADD COLUMN scan_type TEXT NOT NULL DEFAULT 'checks';
CREATE INDEX IF NOT EXISTS idx_scan_runs_type ON scan_runs(scan_type);

-- =============================================================================
-- Seed Data: Reference Tables (INSERT OR IGNORE — safe for re-runs)
-- =============================================================================

INSERT OR IGNORE INTO provider_auth_methods (provider, method, display_name, sort_order) VALUES
('Azure', 'ServicePrincipalSecret', 'Service Principal (Client Secret)', 1),
('Azure', 'ServicePrincipalCertificate', 'Service Principal (Certificate)', 2),
('Azure', 'ManagedIdentity', 'Managed Identity', 3),
('AWS', 'CurrentProfile', 'Current Profile (AWS CLI)', 1),
('AWS', 'AccessKey', 'Access Key', 2);

INSERT OR IGNORE INTO identity_types (name, display_name, type, provider, principal_type, graph_node_type, description) VALUES
('EntraUser', 'User', 'Human', 'Azure', 'User', 'EntraUser', 'Microsoft Entra ID user account (member or guest)'),
('EntraGroup', 'Group', 'Collection', 'Azure', 'Group', 'EntraGroup', 'Microsoft Entra ID security or Microsoft 365 group'),
('EntraServicePrincipal', 'Service Principal', 'Workload', 'Azure', 'ServicePrincipal', 'EntraServicePrincipal', 'Application service principal registered in Entra ID'),
('EntraManagedIdentity', 'Managed Identity', 'Workload', 'Azure', 'ServicePrincipal', 'EntraServicePrincipal', 'System-assigned or user-assigned managed identity (represented as service principal in Entra ID)'),
('EntraApplication', 'Application', 'Workload', 'Azure', NULL, 'EntraApplication', 'Application registration (backing object for a service principal)');

INSERT OR IGNORE INTO resource_types (name, display_name, provider, service_name, arm_provider_prefix, arn_service_prefix) VALUES
('NetworkSecurityGroup', 'Network Security Group', 'Azure', 'Network', 'Microsoft.Network/networkSecurityGroups', NULL),
('ResourceGroup', 'Resource Group', 'Azure', NULL, 'Microsoft.Resources/subscriptions/resourceGroups', NULL),
('Subscription', 'Subscription', 'Azure', NULL, NULL, NULL),
('VirtualMachine', 'Virtual Machine', 'Azure', 'Vm', 'Microsoft.Compute/virtualMachines', NULL),
('EC2Instance', 'EC2 Instance', 'AWS', 'EC2', NULL, 'ec2');

INSERT OR IGNORE INTO permission_relationships (target_type, permission, relationship) VALUES
('VirtualMachine', 'Microsoft.Compute/virtualMachines/*', 'CAN_MANAGE'),
('VirtualMachine', 'Microsoft.Compute/virtualMachines/read', 'CAN_READ'),
('VirtualMachine', 'Microsoft.Compute/virtualMachines/write', 'CAN_WRITE'),
('VirtualMachine', 'Microsoft.Compute/virtualMachines/start/action', 'CAN_WRITE'),
('VirtualMachine', 'Microsoft.Compute/virtualMachines/restart/action', 'CAN_WRITE'),
('NetworkSecurityGroup', 'Microsoft.Network/networkSecurityGroups/*', 'CAN_MANAGE'),
('NetworkSecurityGroup', 'Microsoft.Network/networkSecurityGroups/read', 'CAN_READ'),
('NetworkSecurityGroup', 'Microsoft.Network/networkSecurityGroups/write', 'CAN_WRITE'),
('NetworkSecurityGroup', 'Microsoft.Network/networkSecurityGroups/securityRules/write', 'CAN_WRITE'),
('Subscription', '*', 'CAN_MANAGE'),
('Subscription', '*/read', 'CAN_READ'),
('ResourceGroup', 'Microsoft.Resources/subscriptions/resourceGroups/*', 'CAN_MANAGE'),
('ResourceGroup', 'Microsoft.Resources/subscriptions/resourceGroups/read', 'CAN_READ'),
('ResourceGroup', 'Microsoft.Resources/subscriptions/resourceGroups/write', 'CAN_WRITE');

-- =============================================================================
-- Seed Data: Providers (INSERT OR IGNORE — safe for re-runs)
-- =============================================================================

INSERT OR IGNORE INTO providers (id, name, type, enabled, is_default, created_at, updated_at) VALUES
('azure', 'Azure', 'Azure', 1, 1, datetime('now'), datetime('now')),
('aws', 'AWS', 'AWS', 0, 0, datetime('now'), datetime('now'));
