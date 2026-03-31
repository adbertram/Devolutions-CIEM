-- Graph Schema for Attack Path Discovery
-- Applied by module init alongside discovery_schema.sql
-- Tables: graph_nodes, graph_edges

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
