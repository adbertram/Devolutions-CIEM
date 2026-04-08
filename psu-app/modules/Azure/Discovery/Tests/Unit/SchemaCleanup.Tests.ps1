BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    # Create isolated test DB with base + azure + discovery schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    foreach ($schemaPath in @(
        (Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'),
        (Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql')
    )) {
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            $trimmed = $statement.Trim()
            try {
                Invoke-CIEMQuery -Query $trimmed -AsNonQuery | Out-Null
            }
            catch {
                if ($trimmed -match 'ALTER\s+TABLE' -and $_.Exception.Message -match 'duplicate column') {
                    continue
                }
                throw
            }
        }
    }
}

Describe 'Schema Cleanup' {

    Context 'New discovery tables exist' {
        It 'azure_arm_resources table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_arm_resources'"
            $tables | Should -Not -BeNullOrEmpty
        }

        It 'azure_entra_resources table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_entra_resources'"
            $tables | Should -Not -BeNullOrEmpty
        }

        It 'azure_resource_types table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_resource_types'"
            $tables | Should -Not -BeNullOrEmpty
        }

        It 'azure_discovery_runs table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_discovery_runs'"
            $tables | Should -Not -BeNullOrEmpty
        }

        It 'azure_resource_relationships table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_resource_relationships'"
            $tables | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Old tables do NOT exist' {
        It 'azure_service_data table does not exist' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_service_data'"
            $tables | Should -BeNullOrEmpty
        }

        It 'azure_resources table does not exist' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_resources'"
            $tables | Should -BeNullOrEmpty
        }

        It 'azure_resource_properties table does not exist' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_resource_properties'"
            $tables | Should -BeNullOrEmpty
        }

        It 'identity_types table does not exist' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='identity_types'"
            $tables | Should -BeNullOrEmpty
        }

        It 'resource_types table does not exist' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='resource_types'"
            $tables | Should -BeNullOrEmpty
        }

        It 'permission_relationships table does not exist' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='permission_relationships'"
            $tables | Should -BeNullOrEmpty
        }

        It 'identity_resource_access table does not exist' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='identity_resource_access'"
            $tables | Should -BeNullOrEmpty
        }
    }

    Context 'Retained tables still exist' {
        It 'providers table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='providers'"
            $tables | Should -Not -BeNullOrEmpty
        }

        It 'checks table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='checks'"
            $tables | Should -Not -BeNullOrEmpty
        }

        It 'scan_runs table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='scan_runs'"
            $tables | Should -Not -BeNullOrEmpty
        }

        It 'scan_results table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='scan_results'"
            $tables | Should -Not -BeNullOrEmpty
        }

        It 'azure_provider_apis table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_provider_apis'"
            $tables | Should -Not -BeNullOrEmpty
        }

        It 'provider_auth_methods table exists' {
            $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='provider_auth_methods'"
            $tables | Should -Not -BeNullOrEmpty
        }
    }

    Context 'providers table has no is_default column' {
        It 'PRAGMA table_info(providers) does not include is_default' {
            $cols = Invoke-CIEMQuery -Query "PRAGMA table_info(providers)"
            $cols.name | Should -Not -Contain 'is_default'
        }
    }

    Context 'Discovery table indexes exist' {
        It 'idx_arm_resources_type index exists' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_arm_resources_type'"
            $idx | Should -Not -BeNullOrEmpty
        }

        It 'idx_arm_resources_subscription index exists' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_arm_resources_subscription'"
            $idx | Should -Not -BeNullOrEmpty
        }

        It 'idx_entra_resources_type index exists' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_entra_resources_type'"
            $idx | Should -Not -BeNullOrEmpty
        }

        It 'idx_entra_resources_parent_id index exists' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_entra_resources_parent_id'"
            $idx | Should -Not -BeNullOrEmpty
        }

        It 'idx_resource_types_api_source index exists' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_resource_types_api_source'"
            $idx | Should -Not -BeNullOrEmpty
        }

        It 'idx_discovery_runs_status index exists' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_discovery_runs_status'"
            $idx | Should -Not -BeNullOrEmpty
        }

        It 'idx_resource_rel_source index exists' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_resource_rel_source'"
            $idx | Should -Not -BeNullOrEmpty
        }

        It 'idx_resource_rel_target index exists' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_resource_rel_target'"
            $idx | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Discovery schema SQL file exists' {
        It 'psu-app/modules/Azure/Discovery/Data/discovery_schema.sql exists on disk' {
            Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql' | Should -Exist
        }
    }
}
