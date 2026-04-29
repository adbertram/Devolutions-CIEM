BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
}

Describe 'Check catalog state overlay' {
    BeforeEach {
        $script:TestDatabasePath = Join-Path $TestDrive ("ciem-" + [guid]::NewGuid().ToString('N') + '.db')
        $env:CIEM_TEST_DB_PATH = $script:TestDatabasePath
        New-CIEMDatabase -Path $script:TestDatabasePath

        InModuleScope Devolutions.CIEM {
            $script:DatabasePath = $env:CIEM_TEST_DB_PATH
        }

        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    }

    It 'Creates a fresh checks table containing only mutable state columns' {
        $columns = @(
            Invoke-CIEMQuery -Query 'PRAGMA table_info(checks)' |
                Select-Object -ExpandProperty name
        )

        $columns | Should -Be @('id', 'disabled')
    }

    It 'Migrates a legacy metadata checks table to mutable state only' {
        $connection = Open-PSUSQLiteConnection -Database $script:TestDatabasePath
        try {
            Invoke-PSUSQLiteQuery -Connection $connection -Query 'PRAGMA foreign_keys=OFF' -AsNonQuery | Out-Null
            Invoke-PSUSQLiteQuery -Connection $connection -Query 'DROP TABLE checks' -AsNonQuery | Out-Null
            Invoke-PSUSQLiteQuery -Connection $connection -Query @"
CREATE TABLE checks (
    id TEXT PRIMARY KEY,
    provider TEXT NOT NULL,
    service TEXT NOT NULL,
    title TEXT NOT NULL,
    severity TEXT NOT NULL,
    check_script TEXT NOT NULL,
    disabled INTEGER NOT NULL DEFAULT 0
)
"@ -AsNonQuery | Out-Null
            Invoke-PSUSQLiteQuery -Connection $connection -Query @"
INSERT INTO checks (id, provider, service, title, severity, check_script, disabled)
VALUES ('entra_security_defaults_enabled', 'Azure', 'Entra', 'stale title', 'critical', 'Test-EntraSecurityDefaultsEnabled.ps1', 1)
"@ -AsNonQuery | Out-Null
            Invoke-PSUSQLiteQuery -Connection $connection -Query 'PRAGMA foreign_keys=ON' -AsNonQuery | Out-Null
        }
        finally {
            $connection.Dispose()
        }

        InModuleScope Devolutions.CIEM {
            UpdateCIEMCheckStorageSchema
        }

        $columns = @(
            Invoke-CIEMQuery -Query 'PRAGMA table_info(checks)' |
                Select-Object -ExpandProperty name
        )
        $state = Invoke-CIEMQuery -Query 'SELECT id, disabled FROM checks WHERE id = @id' -Parameters @{
            id = 'entra_security_defaults_enabled'
        }

        $columns | Should -Be @('id', 'disabled')
        [int]$state.disabled | Should -Be 1
    }

    It 'Returns catalog metadata when the checks table has no rows' {
        Invoke-CIEMQuery -Query 'DELETE FROM checks' -AsNonQuery | Out-Null

        $check = Get-CIEMCheck -CheckId 'entra_security_defaults_enabled'

        $check.Id | Should -Be 'entra_security_defaults_enabled'
        $check.Title | Should -Be 'Microsoft Entra ID tenant has Security Defaults enabled'
        $check.CheckScript | Should -Be 'Test-EntraSecurityDefaultsEnabled.ps1'
        $check.ExecutionMode | Should -Be 'script'
        @($check.DataNeeds) | Should -Contain 'entra:securitydefaults'
        $check.Disabled | Should -BeFalse
    }

    It 'Overlays disabled state from the checks table onto catalog metadata' {
        Invoke-CIEMQuery -Query 'DELETE FROM checks' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'INSERT INTO checks (id, disabled) VALUES (@id, @disabled)' -Parameters @{
            id = 'entra_security_defaults_enabled'
            disabled = 1
        } -AsNonQuery | Out-Null

        $check = Get-CIEMCheck -CheckId 'entra_security_defaults_enabled'

        $check.Title | Should -Be 'Microsoft Entra ID tenant has Security Defaults enabled'
        $check.Disabled | Should -BeTrue
    }

    It 'Creates disabled state for a catalog check that has no existing state row' {
        Invoke-CIEMQuery -Query 'DELETE FROM checks' -AsNonQuery | Out-Null

        Disable-CIEMCheck -CheckId 'entra_security_defaults_enabled'

        $state = Invoke-CIEMQuery -Query 'SELECT id, disabled FROM checks WHERE id = @id' -Parameters @{
            id = 'entra_security_defaults_enabled'
        }
        $state.id | Should -Be 'entra_security_defaults_enabled'
        [int]$state.disabled | Should -Be 1
        (Get-CIEMCheck -CheckId 'entra_security_defaults_enabled').Disabled | Should -BeTrue
    }

    It 'Throws when disabling an unknown check id' {
        { Disable-CIEMCheck -CheckId 'missing_check_id' } |
            Should -Throw -ExpectedMessage "*Check 'missing_check_id' not found*"
    }

    It 'Throws when enabling an unknown check id' {
        { Enable-CIEMCheck -CheckId 'missing_check_id' } |
            Should -Throw -ExpectedMessage "*Check 'missing_check_id' not found*"
    }

    It 'Rejects static metadata updates because catalog rows are authoritative' {
        {
            Update-CIEMCheck -Id 'entra_security_defaults_enabled' -Title 'Changed title'
        } | Should -Throw "*Only disabled state can be updated*"

        (Get-CIEMCheck -CheckId 'entra_security_defaults_enabled').Title | Should -Be 'Microsoft Entra ID tenant has Security Defaults enabled'
    }

    It 'Updates disabled state without changing catalog metadata' {
        $updated = Update-CIEMCheck -Id 'entra_security_defaults_enabled' -Disabled $true -PassThru

        $updated.Disabled | Should -BeTrue
        $updated.Title | Should -Be 'Microsoft Entra ID tenant has Security Defaults enabled'
        $updated.CheckScript | Should -Be 'Test-EntraSecurityDefaultsEnabled.ps1'
    }
}
