-- CIEM Database Schema (Generic Tables)
-- SQLite with WAL mode for concurrent read support
-- All tables use IF NOT EXISTS for idempotent creation
-- Azure-specific tables are in Devolutions.CIEM.Azure.Infrastructure/Data/azure_schema.sql
-- Azure permissions tables are in Devolutions.CIEM.Azure.Permissions/Data/azure_permissions_schema.sql

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
