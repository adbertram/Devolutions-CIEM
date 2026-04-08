@{
    # Save-CIEMAzure* table configuration.
    #
    # Each entry describes a target table for bulk INSERT OR REPLACE via the generic
    # SaveCIEMAzureTable core. Column lists are the authoritative source for the
    # multi-row INSERT statement; a drift test asserts they stay in sync with
    # discovery_schema.sql.
    #
    # Column order does NOT need to match the schema column order — it only needs
    # to be a set-equal match. The generic helper maps column names to PascalCase
    # property names on the input objects (e.g., 'subscription_id' -> 'SubscriptionId').
    #
    # AUTOINCREMENT id columns MUST be omitted (the insert doesn't specify them).

    ArmResource = @{
        Table = 'azure_arm_resources'
        Columns = @(
            'id', 'type', 'name', 'location', 'resource_group', 'subscription_id',
            'tenant_id', 'kind', 'sku', 'identity', 'managed_by', 'plan', 'zones',
            'tags', 'properties', 'collected_at', 'last_seen_at'
        )
    }

    EntraResource = @{
        Table = 'azure_entra_resources'
        Columns = @(
            'id', 'type', 'display_name', 'parent_id', 'properties',
            'collected_at', 'last_seen_at'
        )
    }

    ResourceRelationship = @{
        Table = 'azure_resource_relationships'
        Columns = @(
            'source_id', 'source_type', 'target_id', 'target_type',
            'relationship', 'collected_at'
        )
    }

    EffectiveRoleAssignment = @{
        Table = 'azure_effective_role_assignments'
        Columns = @(
            'principal_id', 'principal_type', 'principal_display_name',
            'original_principal_id', 'original_principal_type',
            'role_definition_id', 'role_name', 'scope', 'permissions_json',
            'computed_at'
        )
    }
}
