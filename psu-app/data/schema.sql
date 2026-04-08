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
    depends_on TEXT,
    data_needs TEXT
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

-- scan_type column and index are part of the CREATE TABLE definition above.
-- The ALTER TABLE migration that was here has been removed since the column
-- was already included in the table definition.
CREATE INDEX IF NOT EXISTS idx_scan_runs_type ON scan_runs(scan_type);

ALTER TABLE checks ADD COLUMN data_needs TEXT;

-- =============================================================================
-- Provider Authentication Methods
-- =============================================================================

CREATE TABLE IF NOT EXISTS provider_auth_methods (
    provider TEXT NOT NULL,
    method TEXT NOT NULL,
    display_name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (provider, method)
);

-- =============================================================================
-- Seed Data: Providers (INSERT OR IGNORE — safe for re-runs)
-- =============================================================================

INSERT OR IGNORE INTO providers (id, name, type, enabled, created_at, updated_at) VALUES
('azure', 'Azure', 'Azure', 1, datetime('now'), datetime('now')),
('aws', 'AWS', 'AWS', 0, datetime('now'), datetime('now'));

-- =============================================================================
-- Seed Data: Provider Authentication Methods (INSERT OR IGNORE — safe for re-runs)
-- =============================================================================

INSERT OR IGNORE INTO provider_auth_methods (provider, method, display_name, sort_order) VALUES
('Azure', 'ServicePrincipalSecret', 'Service Principal (Secret)', 1),
('Azure', 'ServicePrincipalCertificate', 'Service Principal (Certificate)', 2),
('Azure', 'ManagedIdentity', 'Managed Identity', 3),
('AWS', 'CurrentProfile', 'Current Profile', 1),
('AWS', 'AccessKey', 'Access Key', 2);
