BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Get-CIEMScanEfficiencySummary' {
    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM scan_results' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM scan_runs' -AsNonQuery | Out-Null
    }

    It 'exports the scan efficiency summary command' {
        Get-Command Get-CIEMScanEfficiencySummary -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'returns NoScanData when no timed terminal scan runs exist' {
        Invoke-CIEMQuery -Query @"
INSERT INTO scan_runs (
    id, provider_id, scan_type, status, resource_providers, include_passed,
    started_at, total_results, failed_results, passed_results, skipped_results, manual_results
)
VALUES (
    'running-scan', 'azure', 'checks', 'Running', 'Azure', 1,
    '2026-05-07T01:00:00Z', 0, 0, 0, 0, 0
)
"@ -AsNonQuery | Out-Null

        $summary = Get-CIEMScanEfficiencySummary

        $summary.Status | Should -Be 'NoScanData'
        $summary.RunCount | Should -Be 0
        $summary.Runs | Should -HaveCount 0
    }

    It 'computes duration, throughput, totals, latest run, and slowest run' {
        Invoke-CIEMQuery -Query @"
INSERT INTO scan_runs (
    id, provider_id, scan_type, status, resource_providers, include_passed,
    started_at, completed_at, duration_seconds, total_results, failed_results,
    passed_results, skipped_results, manual_results
)
VALUES
('scan-old', 'azure', 'checks', 'Completed', 'Azure', 1, '2026-05-07T01:00:00Z', '2026-05-07T01:01:40Z', 100, 50, 5, 40, 3, 2),
('scan-new', 'azure', 'checks', 'Completed', 'Azure,AWS', 1, '2026-05-07T02:00:00Z', '2026-05-07T02:00:20Z', 20, 10, 1, 8, 1, 0)
"@ -AsNonQuery | Out-Null

        $summary = Get-CIEMScanEfficiencySummary -Last 5

        $summary.Status | Should -Be 'Tracked'
        $summary.RunCount | Should -Be 2
        $summary.LatestRunId | Should -Be 'scan-new'
        $summary.LatestDurationSeconds | Should -Be 20
        $summary.LatestResultsPerSecond | Should -Be 0.5
        $summary.AverageDurationSeconds | Should -Be 60
        $summary.AverageResultsPerSecond | Should -Be 0.5
        $summary.SlowestRunId | Should -Be 'scan-old'
        $summary.SlowestDurationSeconds | Should -Be 100
        $summary.TotalResults | Should -Be 60
        $summary.FailedResults | Should -Be 6
        $summary.PassedResults | Should -Be 48
        $summary.SkippedResults | Should -Be 4
        $summary.ManualResults | Should -Be 2
        $summary.Runs[0].Providers | Should -Contain 'AWS'
    }

    It 'honors the -Last limit before aggregating metrics' {
        Invoke-CIEMQuery -Query @"
INSERT INTO scan_runs (
    id, provider_id, scan_type, status, resource_providers, include_passed,
    started_at, completed_at, duration_seconds, total_results, failed_results,
    passed_results, skipped_results, manual_results
)
VALUES
('scan-1', 'azure', 'checks', 'Completed', 'Azure', 1, '2026-05-07T01:00:00Z', '2026-05-07T01:00:10Z', 10, 10, 1, 9, 0, 0),
('scan-2', 'azure', 'checks', 'Completed', 'Azure', 1, '2026-05-07T02:00:00Z', '2026-05-07T02:00:20Z', 20, 20, 2, 18, 0, 0),
('scan-3', 'azure', 'checks', 'Completed', 'Azure', 1, '2026-05-07T03:00:00Z', '2026-05-07T03:00:30Z', 30, 30, 3, 27, 0, 0)
"@ -AsNonQuery | Out-Null

        $summary = Get-CIEMScanEfficiencySummary -Last 2

        $summary.RunCount | Should -Be 2
        $summary.TotalResults | Should -Be 50
        $summary.Runs.Id | Should -Contain 'scan-3'
        $summary.Runs.Id | Should -Contain 'scan-2'
        $summary.Runs.Id | Should -Not -Contain 'scan-1'
    }
}
