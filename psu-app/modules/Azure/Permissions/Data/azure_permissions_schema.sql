-- Azure Permissions Schema
-- Applied by Azure/Permissions module at import time
-- All tables use IF NOT EXISTS for idempotent creation

-- =============================================================================
-- Azure Scope Table (RBAC scope definitions)
-- =============================================================================

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
