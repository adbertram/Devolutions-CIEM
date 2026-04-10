BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

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
            Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    }
}

Describe 'Stop-CIEMAzureDiscovery' {

    Context 'Command structure' {
        It 'is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Stop-CIEMAzureDiscovery -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'supports ShouldProcess (WhatIf/Confirm)' {
            $cmd = Get-Command -Module Devolutions.CIEM -Name Stop-CIEMAzureDiscovery
            $cmd.Parameters.ContainsKey('WhatIf') | Should -BeTrue
            $cmd.Parameters.ContainsKey('Confirm') | Should -BeTrue
        }
    }

    Context 'when a running discovery run exists' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
            New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt '2026-03-01T00:00:00Z'
        }

        It 'sets the discovery run status to Cancelled' {
            Stop-CIEMAzureDiscovery
            $cancelled = @(Get-CIEMAzureDiscoveryRun -Status 'Cancelled')
            $cancelled | Should -HaveCount 1
            $cancelled[0].Status | Should -Be 'Cancelled'
        }

        It 'sets CompletedAt timestamp' {
            Stop-CIEMAzureDiscovery
            $cancelled = @(Get-CIEMAzureDiscoveryRun -Status 'Cancelled')
            $cancelled[0].CompletedAt | Should -Not -BeNullOrEmpty
        }

        It 'sets ErrorMessage to indicate user cancellation' {
            Stop-CIEMAzureDiscovery
            $cancelled = @(Get-CIEMAzureDiscoveryRun -Status 'Cancelled')
            $cancelled[0].ErrorMessage | Should -Be 'Cancelled by user'
        }
    }

    Context 'when multiple running discovery runs exist' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
            $script:run1 = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt '2026-03-01T00:00:00Z'
            $script:run2 = New-CIEMAzureDiscoveryRun -Scope 'ARM' -Status 'Running' -StartedAt '2026-03-01T01:00:00Z'
        }

        It 'cancels all running discovery runs' {
            Stop-CIEMAzureDiscovery
            $running = @(Get-CIEMAzureDiscoveryRun -Status 'Running')
            $running | Should -HaveCount 0
            $cancelled = @(Get-CIEMAzureDiscoveryRun -Status 'Cancelled')
            $cancelled | Should -HaveCount 2
        }
    }

    Context 'when no running discovery run exists' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
            New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-03-01T00:00:00Z' -CompletedAt '2026-03-01T01:00:00Z'
        }

        It 'does not throw' {
            { Stop-CIEMAzureDiscovery } | Should -Not -Throw
        }

        It 'does not modify completed discovery runs' {
            Stop-CIEMAzureDiscovery
            $completed = @(Get-CIEMAzureDiscoveryRun -Status 'Completed')
            $completed | Should -HaveCount 1
        }
    }

    Context 'when -WhatIf is used' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
            New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt '2026-03-01T00:00:00Z'
        }

        It 'does not cancel the discovery run' {
            Stop-CIEMAzureDiscovery -WhatIf
            $running = @(Get-CIEMAzureDiscoveryRun -Status 'Running')
            $running | Should -HaveCount 1
            $running[0].Status | Should -Be 'Running'
        }
    }
}
