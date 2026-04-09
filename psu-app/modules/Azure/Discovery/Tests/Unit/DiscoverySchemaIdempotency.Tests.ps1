BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    $script:azureSchemaPath     = Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'
    $script:discoverySchemaPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'

    # Apply the discovery schema without swallowing any errors. A well-formed
    # idempotent schema MUST apply cleanly whether the target DB is empty or
    # already has the schema applied.
    function Invoke-Schema {
        param([string]$Path)
        foreach ($statement in ((Get-Content $Path -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    }
}

Describe 'discovery_schema.sql idempotency' {
    Context 'when applied to a fresh database' {
        BeforeAll {
            New-CIEMDatabase -Path "$TestDrive/fresh.db"
            InModuleScope Devolutions.CIEM {
                $script:DatabasePath = "$TestDrive/fresh.db"
            }
            Invoke-Schema -Path $script:azureSchemaPath
        }

        It 'applies without throwing on the first run' {
            { Invoke-Schema -Path $script:discoverySchemaPath } | Should -Not -Throw
        }

        It 'creates the last_seen index on azure_arm_resources' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_arm_resources_last_seen'"
            $idx | Should -Not -BeNullOrEmpty
        }

        It 'creates the last_seen index on azure_entra_resources' {
            $idx = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_entra_resources_last_seen'"
            $idx | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when re-applied to an already-initialized database' {
        BeforeAll {
            New-CIEMDatabase -Path "$TestDrive/reapply.db"
            InModuleScope Devolutions.CIEM {
                $script:DatabasePath = "$TestDrive/reapply.db"
            }
            Invoke-Schema -Path $script:azureSchemaPath
            Invoke-Schema -Path $script:discoverySchemaPath
        }

        It 'does not throw on the second run (idempotent)' {
            { Invoke-Schema -Path $script:discoverySchemaPath } | Should -Not -Throw
        }
    }
}

Describe 'base schema.sql idempotency' {
    BeforeAll {
        $script:baseSchemaPath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Data' 'schema.sql'
    }

    Context 'when applied via raw SQL to a fresh SQLite file (no catch-swallow)' {
        BeforeAll {
            $script:basePath = "$TestDrive/base.db"
            $conn = Open-PSUSQLiteConnection -Database $script:basePath
            try {
                foreach ($statement in ((Get-Content $script:baseSchemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
                    $script:firstApplyError = $null
                    try { Invoke-PSUSQLiteQuery -Connection $conn -Query $statement.Trim() -AsNonQuery | Out-Null }
                    catch { $script:firstApplyError = $_; break }
                }
            } finally { $conn.Dispose() }
        }

        It 'does not throw any SQLite errors (every ALTER must be idempotent or removed)' {
            $script:firstApplyError | Should -BeNullOrEmpty
        }
    }
}

