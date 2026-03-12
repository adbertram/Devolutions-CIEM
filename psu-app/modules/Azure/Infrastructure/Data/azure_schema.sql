-- Azure Provider Schema
-- Applied by New-CIEMDatabase at module init time
-- Retains only azure_provider_apis + seed data
-- Discovery tables are in Azure/Discovery/Data/discovery_schema.sql

CREATE TABLE IF NOT EXISTS azure_provider_apis (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    base_url TEXT NOT NULL,
    version TEXT
);

-- =============================================================================
-- Azure Provider APIs — Schema Evolution (ALTER TABLE safe for existing DBs)
-- =============================================================================

ALTER TABLE azure_provider_apis ADD COLUMN service TEXT;
ALTER TABLE azure_provider_apis ADD COLUMN path TEXT;
ALTER TABLE azure_provider_apis ADD COLUMN permissions TEXT;
ALTER TABLE azure_provider_apis ADD COLUMN disabled INTEGER NOT NULL DEFAULT 0;

-- =============================================================================
-- Seed Data: Azure Provider APIs (INSERT OR IGNORE — safe for re-runs)
-- =============================================================================

-- Base API rows (URL resolution for Invoke-AzureApi — no service, no path, no permissions)
INSERT OR IGNORE INTO azure_provider_apis (name, base_url, version) VALUES
('ARM', 'https://management.azure.com', NULL),
('Graph', 'https://graph.microsoft.com/v1.0', NULL),
('KeyVault', 'https://vault.azure.net', NULL);

-- Scoped endpoint rows (discovery endpoint registry with permissions)
INSERT OR IGNORE INTO azure_provider_apis (name, base_url, version, service, path, permissions) VALUES
('Graph/users',                   'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/users',                                        '{"Graph":["Directory.Read.All"]}'),
('Graph/users/signInActivity',    'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/users?$select=signInActivity',                  '{"Graph":["AuditLog.Read.All"]}'),
('Graph/groups',                  'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/groups',                                        '{"Graph":["Directory.Read.All"]}'),
('Graph/servicePrincipals',       'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/servicePrincipals',                             '{"Graph":["Directory.Read.All"]}'),
('Graph/applications',            'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/applications',                                  '{"Graph":["Directory.Read.All"]}'),
('Graph/directoryRoles',          'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/directoryRoles',                                '{"Graph":["Directory.Read.All"]}'),
('Graph/appRoleAssignments',      'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/servicePrincipals/{id}/appRoleAssignments',     '{"Graph":["Directory.Read.All"]}'),
('Graph/oauth2PermissionGrants',  'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/oauth2PermissionGrants',                        '{"Graph":["Directory.Read.All"]}'),
('Graph/groupMembers',            'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/groups/{id}/members',                           '{"Graph":["Directory.Read.All"]}'),
('Graph/groupOwners',             'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/groups/{id}/owners',                            '{"Graph":["Directory.Read.All"]}'),
('Graph/directoryRoleMembers',    'https://graph.microsoft.com/v1.0', NULL, 'Entra',         '/directoryRoles/{id}/members',                   '{"Graph":["Directory.Read.All"]}'),
('ARM/resourceGraph',             'https://management.azure.com',     NULL, 'ResourceGraph', '/providers/Microsoft.ResourceGraph/resources',    '{"AzureRoles":["Reader"]}'),
('ARM/roleDefinitions',           'https://management.azure.com',     NULL, 'IAM',           '/providers/Microsoft.Authorization/roleDefinitions', '{"AzureRoles":["Reader"]}');
