-- Azure Provider Schema
-- Applied by Devolutions.CIEM.Azure module at import time
-- All tables use IF NOT EXISTS for idempotent creation

-- =============================================================================
-- Azure Infrastructure Tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_provider_apis (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    base_url TEXT NOT NULL,
    version TEXT
);

CREATE TABLE IF NOT EXISTS azure_resource_types (
    id TEXT PRIMARY KEY,
    provider_api_id INTEGER NOT NULL,
    display_name TEXT NOT NULL,
    is_collectible INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (provider_api_id) REFERENCES azure_provider_apis(id)
);

CREATE INDEX IF NOT EXISTS idx_azure_resource_types_api ON azure_resource_types(provider_api_id);

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
-- Azure Service Data Table (Generic collector storage)
-- =============================================================================

CREATE TABLE IF NOT EXISTS azure_service_data (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    subscription_id TEXT,
    service_name TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    resource_name TEXT,
    data TEXT NOT NULL,
    collected_at TEXT NOT NULL,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_azure_service_data_service ON azure_service_data(provider_id, service_name);
CREATE INDEX IF NOT EXISTS idx_azure_service_data_type ON azure_service_data(provider_id, service_name, resource_type);

-- =============================================================================
-- Seed Data: Azure Provider APIs (INSERT OR IGNORE — safe for re-runs)
-- =============================================================================

INSERT OR IGNORE INTO azure_provider_apis (name, base_url, version) VALUES
('ARM', 'https://management.azure.com', NULL),
('Graph', 'https://graph.microsoft.com/v1.0', NULL),
('KeyVault', 'https://vault.azure.net', NULL);
