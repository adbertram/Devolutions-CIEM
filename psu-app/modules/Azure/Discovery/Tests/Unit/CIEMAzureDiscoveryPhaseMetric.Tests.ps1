BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Azure discovery phase metrics' {
    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM azure_discovery_phase_metrics' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM azure_discovery_runs' -AsNonQuery | Out-Null
    }

    It 'exports phase metric commands and creates the metrics table' {
        Get-Command Get-CIEMAzureDiscoveryPhaseMetric -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command Save-CIEMAzureDiscoveryPhaseMetric -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty

        $tables = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'azure_discovery_phase_metrics'")
        $tables | Should -HaveCount 1
    }

    It 'persists and returns phase timing evidence for a discovery run' {
        $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt '2026-05-07T01:00:00Z'

        $metric = Save-CIEMAzureDiscoveryPhaseMetric `
            -DiscoveryRunId $run.Id `
            -PhaseName 'Graph build' `
            -Succeeded $true `
            -ElapsedSeconds 12.345 `
            -Evidence '42 nodes, 99 edges' `
            -RecordedAt '2026-05-07T01:00:12Z'

        $metric.DiscoveryRunId | Should -Be $run.Id
        $metric.PhaseName | Should -Be 'Graph build'
        $metric.Succeeded | Should -BeTrue
        $metric.ElapsedSeconds | Should -Be 12.35
        $metric.Evidence | Should -Be '42 nodes, 99 edges'

        $stored = @(Get-CIEMAzureDiscoveryPhaseMetric -DiscoveryRunId $run.Id)
        $stored | Should -HaveCount 1
        $stored[0].RecordedAt | Should -Be '2026-05-07T01:00:12Z'
    }

    It 'updates the same run and phase deterministically' {
        $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt '2026-05-07T01:00:00Z'

        Save-CIEMAzureDiscoveryPhaseMetric -DiscoveryRunId $run.Id -PhaseName 'ARM persistence' -Succeeded $true -ElapsedSeconds 3 -Evidence '1 row' | Out-Null
        Save-CIEMAzureDiscoveryPhaseMetric -DiscoveryRunId $run.Id -PhaseName 'ARM persistence' -Succeeded $true -ElapsedSeconds 4 -Evidence '2 rows' | Out-Null

        $stored = @(Get-CIEMAzureDiscoveryPhaseMetric -DiscoveryRunId $run.Id -PhaseName 'ARM persistence')

        $stored | Should -HaveCount 1
        $stored[0].ElapsedSeconds | Should -Be 4
        $stored[0].Evidence | Should -Be '2 rows'
    }

    It 'records metrics from InvokeCIEMDiscoveryPhase when a discovery run id is supplied' {
        $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt '2026-05-07T01:00:00Z'

        InModuleScope Devolutions.CIEM -Parameters @{ RunId = $run.Id } {
            $errors = [System.Collections.Generic.List[string]]::new()
            $warnings = [ref]0

            InvokeCIEMDiscoveryPhase `
                -Name 'MetricPhase' `
                -FailureMode 'FailRun' `
                -ErrorMessages $errors `
                -WarningCounter $warnings `
                -DiscoveryRunId $RunId `
                -DetailBuilder { param($r) "$r row(s)" } `
                -Action { 7 } | Out-Null
        }

        $stored = @(Get-CIEMAzureDiscoveryPhaseMetric -DiscoveryRunId $run.Id -PhaseName 'MetricPhase')

        $stored | Should -HaveCount 1
        $stored[0].Succeeded | Should -BeTrue
        $stored[0].Evidence | Should -Be '7 row(s)'
        $stored[0].ElapsedSeconds | Should -BeGreaterOrEqual 0
    }

    It 'records failure evidence from InvokeCIEMDiscoveryPhase before throwing a fail-run phase' {
        $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt '2026-05-07T01:00:00Z'

        InModuleScope Devolutions.CIEM -Parameters @{ RunId = $run.Id } {
            $errors = [System.Collections.Generic.List[string]]::new()
            $warnings = [ref]0

            {
                InvokeCIEMDiscoveryPhase `
                    -Name 'MetricFailure' `
                    -FailureMode 'FailRun' `
                    -ErrorMessages $errors `
                    -WarningCounter $warnings `
                    -DiscoveryRunId $RunId `
                    -Action { throw 'phase blew up' }
            } | Should -Throw 'MetricFailure failed: phase blew up'
        }

        $stored = @(Get-CIEMAzureDiscoveryPhaseMetric -DiscoveryRunId $run.Id -PhaseName 'MetricFailure')

        $stored | Should -HaveCount 1
        $stored[0].Succeeded | Should -BeFalse
        $stored[0].Evidence | Should -Be 'MetricFailure failed: phase blew up'
    }

    It 'throws when saving a metric for a missing discovery run' {
        {
            Save-CIEMAzureDiscoveryPhaseMetric -DiscoveryRunId 404 -PhaseName 'Missing' -Succeeded $true -ElapsedSeconds 1
        } | Should -Throw "Discovery run '404' was not found."
    }
}
