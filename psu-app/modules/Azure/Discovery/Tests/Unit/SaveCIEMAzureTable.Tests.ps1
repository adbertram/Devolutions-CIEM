BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    $script:EntityConfigPath = Join-Path $PSScriptRoot '..' '..' '..' 'Discovery' 'Data' 'entities.psd1'
    $script:DiscoverySchemaPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'

    function Get-SchemaColumns {
        param(
            [Parameter(Mandatory)][string]$SchemaPath,
            [Parameter(Mandatory)][string]$TableName
        )

        $schemaText = Get-Content -Path $SchemaPath -Raw

        # Extract initial CREATE TABLE block
        $createPattern = '(?is)CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+' + [regex]::Escape($TableName) + '\s*\((.*?)\)\s*;'
        $createMatch = [regex]::Match($schemaText, $createPattern)
        if (-not $createMatch.Success) {
            throw "Could not find CREATE TABLE $TableName in $SchemaPath"
        }

        $body = $createMatch.Groups[1].Value
        $columns = [System.Collections.Generic.List[string]]::new()
        foreach ($line in ($body -split "`n")) {
            $trimmed = $line.Trim().TrimEnd(',')
            if (-not $trimmed) { continue }
            if ($trimmed -match '^(UNIQUE|PRIMARY\s+KEY|FOREIGN\s+KEY|CHECK|CONSTRAINT)\b') { continue }
            if ($trimmed -match '^([a-zA-Z_][a-zA-Z0-9_]*)\s+') {
                $columns.Add($Matches[1])
            }
        }

        # Handle ALTER TABLE ... ADD COLUMN for subsequent schema migrations
        $alterPattern = '(?im)^\s*ALTER\s+TABLE\s+' + [regex]::Escape($TableName) + '\s+ADD\s+COLUMN\s+([a-zA-Z_][a-zA-Z0-9_]*)\b'
        foreach ($alterMatch in [regex]::Matches($schemaText, $alterPattern)) {
            $col = $alterMatch.Groups[1].Value
            if (-not $columns.Contains($col)) {
                $columns.Add($col)
            }
        }

        $columns.ToArray()
    }
}

Describe 'entities.psd1 + Save-CIEMAzureTable generic core' {
    It 'entities.psd1 config file exists' {
        $script:EntityConfigPath | Should -Exist
    }

    It 'entities.psd1 is a valid PowerShell data file with entries for all four tables' {
        $config = Import-PowerShellDataFile -Path $script:EntityConfigPath

        $config.Keys | Should -Contain 'ArmResource'
        $config.Keys | Should -Contain 'EntraResource'
        $config.Keys | Should -Contain 'ResourceRelationship'
        $config.Keys | Should -Contain 'EffectiveRoleAssignment'
    }

    It 'Each config entry declares Table and Columns' {
        $config = Import-PowerShellDataFile -Path $script:EntityConfigPath
        foreach ($entityName in 'ArmResource', 'EntraResource', 'ResourceRelationship', 'EffectiveRoleAssignment') {
            $entry = $config[$entityName]
            $entry.Keys | Should -Contain 'Table'
            $entry.Keys | Should -Contain 'InsertColumns'
            $entry.InsertColumns.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Schema drift detection' {
        It 'ArmResource columns match discovery_schema.sql azure_arm_resources' {
            $config = Import-PowerShellDataFile -Path $script:EntityConfigPath
            $configColumns = @($config.ArmResource.InsertColumns)
            $schemaColumns = Get-SchemaColumns -SchemaPath $script:DiscoverySchemaPath -TableName 'azure_arm_resources'
            $missing = @($schemaColumns | Where-Object { $_ -notin $configColumns })
            $extra = @($configColumns | Where-Object { $_ -notin $schemaColumns })
            "missing from config: $($missing -join ', '); extra in config: $($extra -join ', ')" | Should -Be "missing from config: ; extra in config: "
        }

        It 'EntraResource columns match discovery_schema.sql azure_entra_resources' {
            $config = Import-PowerShellDataFile -Path $script:EntityConfigPath
            $configColumns = @($config.EntraResource.InsertColumns)
            $schemaColumns = Get-SchemaColumns -SchemaPath $script:DiscoverySchemaPath -TableName 'azure_entra_resources'
            $missing = @($schemaColumns | Where-Object { $_ -notin $configColumns })
            $extra = @($configColumns | Where-Object { $_ -notin $schemaColumns })
            "missing from config: $($missing -join ', '); extra in config: $($extra -join ', ')" | Should -Be "missing from config: ; extra in config: "
        }

        It 'ResourceRelationship columns match discovery_schema.sql azure_resource_relationships (excluding autoincrement id)' {
            $config = Import-PowerShellDataFile -Path $script:EntityConfigPath
            $configColumns = @($config.ResourceRelationship.InsertColumns)
            # The schema has an AUTOINCREMENT id column that must NOT appear in the PSD1 (inserts don't specify it)
            $schemaColumns = Get-SchemaColumns -SchemaPath $script:DiscoverySchemaPath -TableName 'azure_resource_relationships' | Where-Object { $_ -ne 'id' }
            $missing = @($schemaColumns | Where-Object { $_ -notin $configColumns })
            $extra = @($configColumns | Where-Object { $_ -notin $schemaColumns })
            "missing from config: $($missing -join ', '); extra in config: $($extra -join ', ')" | Should -Be "missing from config: ; extra in config: "
        }

        It 'EffectiveRoleAssignment columns match discovery_schema.sql azure_effective_role_assignments (excluding autoincrement id)' {
            $config = Import-PowerShellDataFile -Path $script:EntityConfigPath
            $configColumns = @($config.EffectiveRoleAssignment.InsertColumns)
            $schemaColumns = Get-SchemaColumns -SchemaPath $script:DiscoverySchemaPath -TableName 'azure_effective_role_assignments' | Where-Object { $_ -ne 'id' }
            $missing = @($schemaColumns | Where-Object { $_ -notin $configColumns })
            $extra = @($configColumns | Where-Object { $_ -notin $schemaColumns })
            "missing from config: $($missing -join ', '); extra in config: $($extra -join ', ')" | Should -Be "missing from config: ; extra in config: "
        }
    }

    Context 'Generic Save-CIEMAzureTable core' {
        It 'Function exists and is private (not exported from the module)' {
            InModuleScope Devolutions.CIEM {
                Get-Command -Name 'SaveCIEMAzureTable' -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'SaveCIEMAzureTable'
        }

        It 'Delegates through InvokeCIEMBatchInsert to the correct table' {
            InModuleScope Devolutions.CIEM {
                $script:capturedTable = $null
                Mock InvokeCIEMBatchInsert {
                    $script:capturedTable = $Table
                }

                SaveCIEMAzureTable -Entity 'ArmResource' -Items @([pscustomobject]@{ Id = 'x'; Type = 't'; Name = 'n' })

                $script:capturedTable | Should -Be 'azure_arm_resources'
            }
        }

        It 'Throws on unknown Entity name' {
            InModuleScope Devolutions.CIEM {
                { SaveCIEMAzureTable -Entity 'NotAThing' -Items @([pscustomobject]@{ x = 1 }) } |
                    Should -Throw '*unknown entity*'
            }
        }
    }

    Context 'Public shim wrappers still exist and still route through the generic core' {
        BeforeEach {
            InModuleScope Devolutions.CIEM {
                $script:shimBatchCalls = [System.Collections.Generic.List[object]]::new()
                Mock InvokeCIEMBatchInsert {
                    $script:shimBatchCalls.Add([pscustomobject]@{
                        Table = $Table
                        Columns = $Columns
                        ItemCount = @($Items).Count
                    })
                }
            }
        }

        It 'Save-CIEMAzureArmResource exists and is exported' {
            Get-Command -Module Devolutions.CIEM -Name 'Save-CIEMAzureArmResource' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureEntraResource exists and is exported' {
            Get-Command -Module Devolutions.CIEM -Name 'Save-CIEMAzureEntraResource' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureResourceRelationship exists and is exported' {
            Get-Command -Module Devolutions.CIEM -Name 'Save-CIEMAzureResourceRelationship' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureEffectiveRoleAssignment exists and is exported' {
            Get-Command -Module Devolutions.CIEM -Name 'Save-CIEMAzureEffectiveRoleAssignment' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureArmResource still accepts ByProperties parameter set' {
            $cmdInfo = Get-Command -Module Devolutions.CIEM -Name 'Save-CIEMAzureArmResource'
            $cmdInfo.ParameterSets.Name | Should -Contain 'ByProperties'
            $cmdInfo.Parameters['Id'] | Should -Not -BeNullOrEmpty
            $cmdInfo.Parameters['Type'] | Should -Not -BeNullOrEmpty
            $cmdInfo.Parameters['Name'] | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureEntraResource still accepts ByProperties parameter set' {
            $cmdInfo = Get-Command -Module Devolutions.CIEM -Name 'Save-CIEMAzureEntraResource'
            $cmdInfo.ParameterSets.Name | Should -Contain 'ByProperties'
            $cmdInfo.Parameters['Id'] | Should -Not -BeNullOrEmpty
            $cmdInfo.Parameters['Type'] | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureResourceRelationship still accepts ByProperties parameter set' {
            $cmdInfo = Get-Command -Module Devolutions.CIEM -Name 'Save-CIEMAzureResourceRelationship'
            $cmdInfo.ParameterSets.Name | Should -Contain 'ByProperties'
            $cmdInfo.Parameters['SourceId'] | Should -Not -BeNullOrEmpty
            $cmdInfo.Parameters['SourceType'] | Should -Not -BeNullOrEmpty
            $cmdInfo.Parameters['TargetId'] | Should -Not -BeNullOrEmpty
            $cmdInfo.Parameters['Relationship'] | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureEffectiveRoleAssignment still accepts ByProperties parameter set' {
            $cmdInfo = Get-Command -Module Devolutions.CIEM -Name 'Save-CIEMAzureEffectiveRoleAssignment'
            $cmdInfo.ParameterSets.Name | Should -Contain 'ByProperties'
            $cmdInfo.Parameters['PrincipalId'] | Should -Not -BeNullOrEmpty
            $cmdInfo.Parameters['RoleDefinitionId'] | Should -Not -BeNullOrEmpty
            $cmdInfo.Parameters['Scope'] | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureArmResource shim routes through the generic core to azure_arm_resources' {
            InModuleScope Devolutions.CIEM {
                Save-CIEMAzureArmResource -Id '/subs/sub1/rg/vm-shim' -Type 'microsoft.compute/virtualmachines' -Name 'vm-shim'
                @($script:shimBatchCalls).Count | Should -Be 1
                $script:shimBatchCalls[0].Table | Should -Be 'azure_arm_resources'
            }
        }

        It 'Save-CIEMAzureEntraResource shim routes to azure_entra_resources' {
            InModuleScope Devolutions.CIEM {
                Save-CIEMAzureEntraResource -Id 'ent-shim' -Type 'user'
                @($script:shimBatchCalls).Count | Should -Be 1
                $script:shimBatchCalls[0].Table | Should -Be 'azure_entra_resources'
            }
        }
    }
}
