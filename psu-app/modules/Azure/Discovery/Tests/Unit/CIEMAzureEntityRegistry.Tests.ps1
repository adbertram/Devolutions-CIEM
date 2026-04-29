BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    $script:EntityConfigPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'entities.psd1'
    $script:DiscoverySchemaPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    foreach ($schemaPath in @(
        (Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'),
        $script:DiscoverySchemaPath
    )) {
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    }

    function Get-SchemaColumns {
        param(
            [Parameter(Mandatory)][string]$SchemaPath,
            [Parameter(Mandatory)][string]$TableName
        )

        $schemaText = Get-Content -Path $SchemaPath -Raw
        $createPattern = '(?is)CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+' + [regex]::Escape($TableName) + '\s*\((.*?)\)\s*;'
        $createMatch = [regex]::Match($schemaText, $createPattern)
        if (-not $createMatch.Success) {
            throw "Could not find CREATE TABLE $TableName in $SchemaPath"
        }

        $columns = [System.Collections.Generic.List[string]]::new()
        foreach ($line in ($createMatch.Groups[1].Value -split "`n")) {
            $trimmed = $line.Trim().TrimEnd(',')
            if (-not $trimmed) { continue }
            if ($trimmed -match '^(UNIQUE|PRIMARY\s+KEY|FOREIGN\s+KEY|CHECK|CONSTRAINT)\b') { continue }
            if ($trimmed -match '^([a-zA-Z_][a-zA-Z0-9_]*)\s+') {
                $columns.Add($Matches[1])
            }
        }

        $columns.ToArray()
    }
}

Describe 'Azure Discovery Entity Registry' {
    It 'Declares one entity registry file for discovery CRUD processors' {
        $script:EntityConfigPath | Should -Exist
    }

    It 'Defines registry entries for all discovery entity tables handled by generic processors' {
        $config = Import-PowerShellDataFile -Path $script:EntityConfigPath

        $config.Keys | Should -Contain 'ArmResource'
        $config.Keys | Should -Contain 'EntraResource'
        $config.Keys | Should -Contain 'ResourceRelationship'
        $config.Keys | Should -Contain 'EffectiveRoleAssignment'
    }

    It 'Every entity declares strict table, class, key, select, insert, filter, writable, and projection metadata' {
        $config = Import-PowerShellDataFile -Path $script:EntityConfigPath

        foreach ($entityName in 'ArmResource', 'EntraResource', 'ResourceRelationship', 'EffectiveRoleAssignment') {
            $entity = $config[$entityName]
            $entity.Keys | Should -Contain 'Table'
            $entity.Keys | Should -Contain 'Class'
            $entity.Keys | Should -Contain 'KeyColumns'
            $entity.Keys | Should -Contain 'SelectColumns'
            $entity.Keys | Should -Contain 'InsertColumns'
            $entity.Keys | Should -Contain 'FilterColumns'
            $entity.Keys | Should -Contain 'WritableColumns'
            $entity.Keys | Should -Contain 'PropertyMap'
            @($entity.SelectColumns).Count | Should -BeGreaterThan 0
            @($entity.InsertColumns).Count | Should -BeGreaterThan 0
            @($entity.FilterColumns.Keys).Count | Should -BeGreaterThan 0
            @($entity.PropertyMap.Keys).Count | Should -BeGreaterThan 0
        }
    }

    It 'ArmResource select columns match discovery schema columns' {
        $config = Import-PowerShellDataFile -Path $script:EntityConfigPath
        $schemaColumns = Get-SchemaColumns -SchemaPath $script:DiscoverySchemaPath -TableName 'azure_arm_resources'
        $missing = @($schemaColumns | Where-Object { $_ -notin @($config.ArmResource.SelectColumns) })
        $extra = @($config.ArmResource.SelectColumns | Where-Object { $_ -notin $schemaColumns })

        "missing from registry: $($missing -join ', '); extra in registry: $($extra -join ', ')" |
            Should -Be 'missing from registry: ; extra in registry: '
    }

    It 'ResourceRelationship insert columns exclude the autoincrement id column' {
        $config = Import-PowerShellDataFile -Path $script:EntityConfigPath

        $config.ResourceRelationship.InsertColumns | Should -Not -Contain 'id'
    }

    It 'GetCIEMAzureEntity returns typed objects from registry projection metadata' {
        Invoke-CIEMQuery -Query @"
INSERT INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at)
VALUES (@id, @type, @name, @location, @resource_group, @subscription_id, @tenant_id, @collected_at)
"@ -Parameters @{
            id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/registry-vm'
            type = 'microsoft.compute/virtualmachines'
            name = 'registry-vm'
            location = 'eastus'
            resource_group = 'rg1'
            subscription_id = 'sub1'
            tenant_id = 'tenant1'
            collected_at = '2026-04-27T00:00:00Z'
        } -AsNonQuery | Out-Null

        $result = InModuleScope Devolutions.CIEM {
            GetCIEMAzureEntity -Entity 'ArmResource' -Filters @{
                Id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/registry-vm'
            }
        }

        $result | Should -HaveCount 1
        $result[0].GetType().Name | Should -Be 'CIEMAzureArmResource'
        $result[0].Name | Should -Be 'registry-vm'
        $result[0].SubscriptionId | Should -Be 'sub1'
    }

    It 'GetCIEMAzureEntity throws for unknown filter names instead of ignoring them' {
        InModuleScope Devolutions.CIEM {
            { GetCIEMAzureEntity -Entity 'ArmResource' -Filters @{ UnknownFilter = 'x' } } |
                Should -Throw '*unknown filter*'
        }
    }

    It 'UpdateCIEMAzureEntity updates declared writable columns without changing other columns' {
        Invoke-CIEMQuery -Query @"
INSERT INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, properties, collected_at)
VALUES (@id, @type, @name, @location, @resource_group, @subscription_id, @properties, @collected_at)
"@ -Parameters @{
            id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/update-vm'
            type = 'microsoft.compute/virtualmachines'
            name = 'update-vm'
            location = 'eastus'
            resource_group = 'rg1'
            subscription_id = 'sub1'
            properties = '{"size":"old"}'
            collected_at = '2026-04-27T00:00:00Z'
        } -AsNonQuery | Out-Null

        InModuleScope Devolutions.CIEM {
            UpdateCIEMAzureEntity -Entity 'ArmResource' -Filters @{
                Id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/update-vm'
            } -Values @{
                Properties = '{"size":"new"}'
            }
        }

        $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/update-vm'
        $result.Name | Should -Be 'update-vm'
        $result.Properties | Should -Be '{"size":"new"}'
    }

    It 'RemoveCIEMAzureEntity deletes only rows matching registry filters' {
        Save-CIEMAzureEntraResource -Id 'delete-user' -Type 'User' -DisplayName 'Delete User'
        Save-CIEMAzureEntraResource -Id 'keep-group' -Type 'Group' -DisplayName 'Keep Group'

        InModuleScope Devolutions.CIEM {
            RemoveCIEMAzureEntity -Entity 'EntraResource' -Filters @{ Type = 'User' }
        }

        Get-CIEMAzureEntraResource -Id 'delete-user' | Should -BeNullOrEmpty
        (Get-CIEMAzureEntraResource -Id 'keep-group').DisplayName | Should -Be 'Keep Group'
    }
}
