BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
}

Describe 'Discovery Classes' {

    Context 'CIEMAzureArmResource class' {
        It 'CIEMAzureArmResource stores and retrieves ARM identity columns (Id, Type, Name, Location, ResourceGroup, SubscriptionId, TenantId)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAzureArmResource]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Id'
            $props | Should -Contain 'Type'
            $props | Should -Contain 'Name'
            $props | Should -Contain 'Location'
            $props | Should -Contain 'ResourceGroup'
            $props | Should -Contain 'SubscriptionId'
            $props | Should -Contain 'TenantId'
        }

        It 'CIEMAzureArmResource stores and retrieves ARM metadata columns (Kind, Sku, Identity, ManagedBy, Plan, Zones, Tags, Properties, CollectedAt)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAzureArmResource]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Kind'
            $props | Should -Contain 'Sku'
            $props | Should -Contain 'Identity'
            $props | Should -Contain 'ManagedBy'
            $props | Should -Contain 'Plan'
            $props | Should -Contain 'Zones'
            $props | Should -Contain 'Tags'
            $props | Should -Contain 'Properties'
            $props | Should -Contain 'CollectedAt'
        }
    }

    Context 'CIEMAzureEntraResource class' {
        It 'CIEMAzureEntraResource stores and retrieves all Entra columns (Id, Type, DisplayName, ParentId, Properties, CollectedAt)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAzureEntraResource]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Id'
            $props | Should -Contain 'Type'
            $props | Should -Contain 'DisplayName'
            $props | Should -Contain 'ParentId'
            $props | Should -Contain 'Properties'
            $props | Should -Contain 'CollectedAt'
        }
    }

    Context 'CIEMAzureResourceType class' {
        It 'CIEMAzureResourceType stores and retrieves all resource type columns (Type, ApiSource, GraphTable, ResourceCount, DiscoveredAt, LastCollected)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAzureResourceType]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Type'
            $props | Should -Contain 'ApiSource'
            $props | Should -Contain 'GraphTable'
            $props | Should -Contain 'ResourceCount'
            $props | Should -Contain 'DiscoveredAt'
            $props | Should -Contain 'LastCollected'
        }
    }

    Context 'CIEMAzureDiscoveryRun class' {
        It 'CIEMAzureDiscoveryRun stores and retrieves run metadata (Id, PsuJobId, Scope, Status, StartedAt, CompletedAt)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAzureDiscoveryRun]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Id'
            $props | Should -Contain 'PsuJobId'
            $props | Should -Contain 'Scope'
            $props | Should -Contain 'Status'
            $props | Should -Contain 'StartedAt'
            $props | Should -Contain 'CompletedAt'
        }

        It 'CIEMAzureDiscoveryRun stores and retrieves count fields (ArmTypeCount, ArmRowCount, EntraTypeCount, EntraRowCount, WarningCount, ErrorMessage)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAzureDiscoveryRun]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'ArmTypeCount'
            $props | Should -Contain 'ArmRowCount'
            $props | Should -Contain 'EntraTypeCount'
            $props | Should -Contain 'EntraRowCount'
            $props | Should -Contain 'WarningCount'
            $props | Should -Contain 'ErrorMessage'
        }
    }

    Context 'CIEMAzureResourceRelationship class' {
        It 'CIEMAzureResourceRelationship stores and retrieves all relationship columns (Id, SourceId, SourceType, TargetId, TargetType, Relationship, CollectedAt)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAzureResourceRelationship]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Id'
            $props | Should -Contain 'SourceId'
            $props | Should -Contain 'SourceType'
            $props | Should -Contain 'TargetId'
            $props | Should -Contain 'TargetType'
            $props | Should -Contain 'Relationship'
            $props | Should -Contain 'CollectedAt'
        }
    }
}
