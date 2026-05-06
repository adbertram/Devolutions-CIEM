@{
    Node = @{
        Table = 'graph_nodes'
        Class = 'CIEMGraphNode'
        KeyColumns = @('id')
        SelectColumns = @(
            'id',
            'kind',
            'display_name',
            'provider',
            'subscription_id',
            'resource_group',
            'properties',
            'collected_at'
        )
        InsertColumns = @(
            'id',
            'kind',
            'display_name',
            'provider',
            'subscription_id',
            'resource_group',
            'properties',
            'collected_at'
        )
        FilterColumns = @{
            Id = 'id'
            Kind = 'kind'
            DisplayName = 'display_name'
            Provider = 'provider'
            SubscriptionId = 'subscription_id'
        }
        WritableColumns = @(
            'Id',
            'Kind',
            'DisplayName',
            'Provider',
            'SubscriptionId',
            'ResourceGroup',
            'Properties',
            'CollectedAt'
        )
        RequiredSaveValues = @('Id', 'Kind')
        PropertyMap = @{
            id = 'Id'
            kind = 'Kind'
            display_name = 'DisplayName'
            provider = 'Provider'
            subscription_id = 'SubscriptionId'
            resource_group = 'ResourceGroup'
            properties = 'Properties'
            collected_at = 'CollectedAt'
        }
    }

    Edge = @{
        Table = 'graph_edges'
        Class = 'CIEMGraphEdge'
        KeyColumns = @('id')
        SelectColumns = @(
            'id',
            'source_id',
            'target_id',
            'kind',
            'properties',
            'computed',
            'collected_at'
        )
        InsertColumns = @(
            'source_id',
            'target_id',
            'kind',
            'properties',
            'computed',
            'collected_at'
        )
        FilterColumns = @{
            Id = 'id'
            SourceId = 'source_id'
            TargetId = 'target_id'
            Kind = 'kind'
            Computed = 'computed'
        }
        WritableColumns = @(
            'SourceId',
            'TargetId',
            'Kind',
            'Properties',
            'Computed',
            'CollectedAt'
        )
        RequiredSaveValues = @('SourceId', 'TargetId', 'Kind')
        PropertyMap = @{
            id = 'Id'
            source_id = 'SourceId'
            target_id = 'TargetId'
            kind = 'Kind'
            properties = 'Properties'
            computed = 'Computed'
            collected_at = 'CollectedAt'
        }
    }
}
