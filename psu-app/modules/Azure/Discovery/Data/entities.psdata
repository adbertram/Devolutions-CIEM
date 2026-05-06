@{
    ArmResource = @{
        Table = 'azure_arm_resources'
        Class = 'CIEMAzureArmResource'
        KeyColumns = @('id')
        SelectColumns = @(
            'id', 'type', 'name', 'location', 'resource_group', 'subscription_id',
            'tenant_id', 'kind', 'sku', 'identity', 'managed_by', 'plan', 'zones',
            'tags', 'properties', 'collected_at', 'last_seen_at'
        )
        InsertColumns = @(
            'id', 'type', 'name', 'location', 'resource_group', 'subscription_id',
            'tenant_id', 'kind', 'sku', 'identity', 'managed_by', 'plan', 'zones',
            'tags', 'properties', 'collected_at', 'last_seen_at'
        )
        FilterColumns = @{
            Id = 'id'
            Type = 'type'
            Name = 'name'
            SubscriptionId = 'subscription_id'
            ResourceGroup = 'resource_group'
        }
        WritableColumns = @(
            'Type', 'Name', 'Location', 'ResourceGroup', 'SubscriptionId',
            'TenantId', 'Kind', 'Sku', 'Identity', 'ManagedBy', 'Plan', 'Zones',
            'Tags', 'Properties', 'CollectedAt', 'LastSeenAt'
        )
        PropertyMap = @{
            id = 'Id'
            type = 'Type'
            name = 'Name'
            location = 'Location'
            resource_group = 'ResourceGroup'
            subscription_id = 'SubscriptionId'
            tenant_id = 'TenantId'
            kind = 'Kind'
            sku = 'Sku'
            identity = 'Identity'
            managed_by = 'ManagedBy'
            plan = 'Plan'
            zones = 'Zones'
            tags = 'Tags'
            properties = 'Properties'
            collected_at = 'CollectedAt'
            last_seen_at = 'LastSeenAt'
        }
    }

    EntraResource = @{
        Table = 'azure_entra_resources'
        Class = 'CIEMAzureEntraResource'
        KeyColumns = @('id')
        SelectColumns = @(
            'id', 'type', 'display_name', 'parent_id', 'properties',
            'collected_at', 'last_seen_at'
        )
        InsertColumns = @(
            'id', 'type', 'display_name', 'parent_id', 'properties',
            'collected_at', 'last_seen_at'
        )
        FilterColumns = @{
            Id = 'id'
            Type = 'type'
            DisplayName = 'display_name'
            ParentId = 'parent_id'
        }
        WritableColumns = @(
            'Type', 'DisplayName', 'ParentId', 'Properties', 'CollectedAt', 'LastSeenAt'
        )
        PropertyMap = @{
            id = 'Id'
            type = 'Type'
            display_name = 'DisplayName'
            parent_id = 'ParentId'
            properties = 'Properties'
            collected_at = 'CollectedAt'
            last_seen_at = 'LastSeenAt'
        }
    }

    ResourceRelationship = @{
        Table = 'azure_resource_relationships'
        Class = 'CIEMAzureResourceRelationship'
        KeyColumns = @('id')
        SelectColumns = @(
            'id', 'source_id', 'source_type', 'target_id', 'target_type',
            'relationship', 'collected_at'
        )
        InsertColumns = @(
            'source_id', 'source_type', 'target_id', 'target_type',
            'relationship', 'collected_at'
        )
        FilterColumns = @{
            Id = 'id'
            SourceId = 'source_id'
            SourceType = 'source_type'
            TargetId = 'target_id'
            TargetType = 'target_type'
            Relationship = 'relationship'
        }
        WritableColumns = @(
            'SourceId', 'SourceType', 'TargetId', 'TargetType', 'Relationship', 'CollectedAt'
        )
        PropertyMap = @{
            id = 'Id'
            source_id = 'SourceId'
            source_type = 'SourceType'
            target_id = 'TargetId'
            target_type = 'TargetType'
            relationship = 'Relationship'
            collected_at = 'CollectedAt'
        }
    }

    EffectiveRoleAssignment = @{
        Table = 'azure_effective_role_assignments'
        Class = 'CIEMAzureEffectiveRoleAssignment'
        KeyColumns = @('id')
        SelectColumns = @(
            'id', 'principal_id', 'principal_type', 'principal_display_name',
            'original_principal_id', 'original_principal_type', 'role_definition_id',
            'role_name', 'scope', 'permissions_json', 'computed_at'
        )
        InsertColumns = @(
            'principal_id', 'principal_type', 'principal_display_name',
            'original_principal_id', 'original_principal_type', 'role_definition_id',
            'role_name', 'scope', 'permissions_json', 'computed_at'
        )
        FilterColumns = @{
            Id = 'id'
            PrincipalId = 'principal_id'
            PrincipalType = 'principal_type'
            OriginalPrincipalId = 'original_principal_id'
            RoleDefinitionId = 'role_definition_id'
            Scope = 'scope'
        }
        WritableColumns = @(
            'PrincipalId', 'PrincipalType', 'PrincipalDisplayName',
            'OriginalPrincipalId', 'OriginalPrincipalType', 'RoleDefinitionId',
            'RoleName', 'Scope', 'PermissionsJson', 'ComputedAt'
        )
        PropertyMap = @{
            id = 'Id'
            principal_id = 'PrincipalId'
            principal_type = 'PrincipalType'
            principal_display_name = 'PrincipalDisplayName'
            original_principal_id = 'OriginalPrincipalId'
            original_principal_type = 'OriginalPrincipalType'
            role_definition_id = 'RoleDefinitionId'
            role_name = 'RoleName'
            scope = 'Scope'
            permissions_json = 'PermissionsJson'
            computed_at = 'ComputedAt'
        }
    }
}
