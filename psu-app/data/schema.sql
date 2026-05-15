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
    disabled INTEGER NOT NULL DEFAULT 0
);

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

-- =============================================================================
-- Authentication Profile Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS authentication_profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    provider TEXT NOT NULL,
    method TEXT NOT NULL,
    settings_json TEXT NOT NULL,
    secret_refs_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS authentication_profile_assignments (
    usage_type TEXT NOT NULL,
    usage_id TEXT NOT NULL,
    authentication_profile_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (usage_type, usage_id),
    FOREIGN KEY (authentication_profile_id) REFERENCES authentication_profiles(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_auth_profile_provider ON authentication_profiles(provider, method);
CREATE INDEX IF NOT EXISTS idx_auth_profile_assignment_profile ON authentication_profile_assignments(authentication_profile_id);

-- Remove the legacy auto-created Azure Default profile. Auth profiles are user-managed.
DELETE FROM authentication_profile_assignments
WHERE usage_type = 'ProviderDiscovery'
AND usage_id = 'Azure'
AND authentication_profile_id = 'sp-clientsecret';

DELETE FROM authentication_profiles
WHERE id = 'sp-clientsecret'
AND name = 'Default'
AND provider = 'Azure'
AND method = 'ServicePrincipalSecret';

-- =============================================================================
-- Notification Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS notification_channels (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 0,
    from_address TEXT NOT NULL,
    to_recipients_json TEXT NOT NULL,
    cc_recipients_json TEXT NOT NULL,
    bcc_recipients_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notification_channels_enabled ON notification_channels(enabled);

CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 0,
    auto_send_scope TEXT NOT NULL,
    change_types_json TEXT NOT NULL,
    minimum_severity TEXT NOT NULL,
    subject_template TEXT NOT NULL,
    text_body_template TEXT NOT NULL,
    html_body_template TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_enabled ON notifications(enabled);

CREATE TABLE IF NOT EXISTS notification_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    notification_id TEXT NOT NULL,
    channel_id TEXT NOT NULL,
    source_signal_id TEXT NOT NULL,
    source_signal_type TEXT NOT NULL,
    status TEXT NOT NULL,
    attempted_at TEXT NOT NULL,
    completed_at TEXT,
    message_id TEXT,
    recipient_summary TEXT,
    error_message TEXT,
    FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE,
    FOREIGN KEY (channel_id) REFERENCES notification_channels(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_notification_history_attempted ON notification_history(attempted_at);
CREATE INDEX IF NOT EXISTS idx_notification_history_source ON notification_history(source_signal_id, source_signal_type);

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
('AWS', 'AccessKey', 'Access Key', 2),
('Email', 'SmtpAnonymous', 'SMTP Anonymous', 1),
('Email', 'SmtpBasic', 'SMTP Basic', 2);
