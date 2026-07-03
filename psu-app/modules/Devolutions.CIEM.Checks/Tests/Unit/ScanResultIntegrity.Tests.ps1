BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'CIEM scan result key integrity' {
    BeforeEach {
        $script:TestDatabasePath = Join-Path $TestDrive ("ciem-" + [guid]::NewGuid().ToString('N') + '.db')
        New-CIEMDatabase -Path $script:TestDatabasePath

        InModuleScope Devolutions.CIEM -Parameters @{ DatabasePath = $script:TestDatabasePath } {
            param([string]$DatabasePath)
            $script:DatabasePath = $DatabasePath
        }
    }

    It 'rejects failed scan results with blank resource ids at creation' {
        $check = [pscustomobject]@{
            Id       = 'sample_check'
            Provider = 'Azure'
        }

        { InModuleScope Devolutions.CIEM -Parameters @{ Check = $check } {
            param([object]$Check)
            [CIEMScanResult]::Create($Check, 'FAIL', 'failed', '', 'resource name', 'Global')
        } } | Should -Throw "*ResourceId is required for failed scan results*"
    }

    It 'allows non-failed scan results without resource ids and failed tenant checks with N/A resource ids' {
        $check = [pscustomobject]@{
            Id       = 'sample_check'
            Provider = 'Azure'
        }

        $pass = InModuleScope Devolutions.CIEM -Parameters @{ Check = $check } {
            param([object]$Check)
            [CIEMScanResult]::Create($Check, 'PASS', 'passed', '', 'resource name', 'Global')
        }
        $tenantFail = InModuleScope Devolutions.CIEM -Parameters @{ Check = $check } {
            param([object]$Check)
            [CIEMScanResult]::Create($Check, 'FAIL', 'failed', 'N/A', 'tenant', 'Global')
        }

        [string]$pass.Status | Should -Be 'PASS'
        [string]$tenantFail.Status | Should -Be 'FAIL'
        $tenantFail.ResourceId | Should -Be 'N/A'
    }

    It 'rejects duplicate failed result keys before persisting scan rows' {
        $check = Get-CIEMCheck -CheckId 'aisearch_service_not_publicly_accessible'
        $scanRun = InModuleScope Devolutions.CIEM -Parameters @{ Check = $check[0] } {
            param([object]$Check)
            $run = [CIEMScanRun]::new(@('Azure'), @(), $true)
            $run.Id = 'duplicate-failed-key'
            $run.Status = [CIEMScanRunStatus]::Completed
            $run.StartTime = [datetime]'2026-05-01T00:00:00Z'
            $run.EndTime = [datetime]'2026-05-01T00:01:00Z'
            $run.ScanResults = @(
                [CIEMScanResult]::Create($Check, 'FAIL', 'failed once', 'resource-1', 'Resource 1', 'Global'),
                [CIEMScanResult]::Create($Check, 'FAIL', 'failed twice', 'resource-1', 'Resource 1', 'Global')
            )
            $run.UpdateCounts()
            $run
        }

        { Save-CIEMScanRun -ScanRun $scanRun } | Should -Throw "*Duplicate failed scan result key 'aisearch_service_not_publicly_accessible|resource-1'*"

        $resultRows = Invoke-CIEMQuery -Query "SELECT scan_run_id FROM scan_results WHERE scan_run_id = 'duplicate-failed-key'"
        $resultRows | Should -HaveCount 0
    }

    It 'writes one historical check snapshot per unique check id when saving results' {
        $check = Get-CIEMCheck -CheckId 'aisearch_service_not_publicly_accessible'
        $scanRun = InModuleScope Devolutions.CIEM -Parameters @{ Check = $check[0] } {
            param([object]$Check)
            $run = [CIEMScanRun]::new(@('Azure'), @(), $true)
            $run.Id = 'snapshot-save'
            $run.Status = [CIEMScanRunStatus]::Completed
            $run.StartTime = [datetime]'2026-05-01T00:00:00Z'
            $run.EndTime = [datetime]'2026-05-01T00:01:00Z'
            $run.ScanResults = @(
                [CIEMScanResult]::Create($Check, 'FAIL', 'failed once', 'resource-1', 'Resource 1', 'Global'),
                [CIEMScanResult]::Create($Check, 'FAIL', 'failed twice', 'resource-2', 'Resource 2', 'Global')
            )
            $run.UpdateCounts()
            $run
        }

        Save-CIEMScanRun -ScanRun $scanRun

        $snapshots = Invoke-CIEMQuery -Query "SELECT check_id, snapshot_json FROM scan_run_check_snapshots WHERE scan_run_id = 'snapshot-save'"
        $payload = $snapshots[0].snapshot_json | ConvertFrom-Json

        $snapshots | Should -HaveCount 1
        $snapshots[0].check_id | Should -Be 'aisearch_service_not_publicly_accessible'
        $payload.id | Should -Be 'aisearch_service_not_publicly_accessible'
        $payload.provider | Should -Be 'Azure'
        $payload.description | Should -Not -BeNullOrEmpty
        $payload.remediation.text | Should -Not -BeNullOrEmpty
    }

    It 'hydrates scan result metadata from the stored snapshot before current catalog metadata' {
        $check = Get-CIEMCheck -CheckId 'aisearch_service_not_publicly_accessible'
        $scanRun = InModuleScope Devolutions.CIEM -Parameters @{ Check = $check[0] } {
            param([object]$Check)
            $run = [CIEMScanRun]::new(@('Azure'), @(), $true)
            $run.Id = 'snapshot-hydration'
            $run.Status = [CIEMScanRunStatus]::Completed
            $run.StartTime = [datetime]'2026-05-01T00:00:00Z'
            $run.EndTime = [datetime]'2026-05-01T00:01:00Z'
            $run.ScanResults = @(
                [CIEMScanResult]::Create($Check, 'FAIL', 'failed once', 'resource-1', 'Resource 1', 'Global')
            )
            $run.UpdateCounts()
            $run
        }
        Save-CIEMScanRun -ScanRun $scanRun
        $historicalSnapshot = @{
            id          = 'aisearch_service_not_publicly_accessible'
            provider    = 'Azure'
            service     = 'Historical Service'
            title       = 'Historical Title'
            description = 'Historical description'
            risk        = 'Historical risk'
            severity    = 'critical'
            remediation = @{ text = 'Historical remediation'; url = 'https://example.invalid/historical' }
            relatedUrl  = 'https://example.invalid/related'
        } | ConvertTo-Json -Compress -Depth 10
        Invoke-CIEMQuery -Query @"
UPDATE scan_run_check_snapshots
SET snapshot_json = @snapshot_json
WHERE scan_run_id = 'snapshot-hydration'
AND check_id = 'aisearch_service_not_publicly_accessible'
"@ -Parameters @{ snapshot_json = $historicalSnapshot } -AsNonQuery | Out-Null

        $results = @(Get-CIEMScanResult -ScanRunId 'snapshot-hydration')

        $results | Should -HaveCount 1
        $results[0].Check.Service | Should -Be 'Historical Service'
        $results[0].Check.Title | Should -Be 'Historical Title'
        $results[0].Check.Severity | Should -Be 'critical'
        $results[0].Check.Remediation.Text | Should -Be 'Historical remediation'
    }

    It 'hydrates scan result metadata from snapshots for retired check ids' {
        Invoke-CIEMQuery -Query @"
INSERT INTO scan_runs (
    id, provider_id, scan_type, status, resource_providers, include_passed,
    started_at, completed_at, duration_seconds, total_results, failed_results,
    passed_results, skipped_results, manual_results
)
VALUES (
    'retired-check-scan', 'azure', 'checks', 'Completed', NULL, 1,
    '2026-05-01T00:00:00Z', '2026-05-01T00:01:00Z', 60, 1, 1, 0, 0, 0
)
"@ -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query "INSERT INTO scan_run_providers (scan_run_id, provider) VALUES ('retired-check-scan', 'Azure')" -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query @"
INSERT INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name, location)
VALUES ('retired-check-scan', 'retired_check_id', 'FAIL', 'still failed historically', 'resource-1', 'Resource 1', 'Global')
"@ -AsNonQuery | Out-Null
        $snapshot = @{
            id          = 'retired_check_id'
            provider    = 'Azure'
            service     = 'Retired Service'
            title       = 'Retired Check Title'
            description = 'Retired description'
            risk        = 'Retired risk'
            severity    = 'high'
            remediation = @{ text = 'Retired remediation'; url = 'https://example.invalid/retired' }
            relatedUrl  = 'https://example.invalid/retired-related'
        } | ConvertTo-Json -Compress -Depth 10
        Invoke-CIEMQuery -Query @"
INSERT INTO scan_run_check_snapshots (scan_run_id, check_id, snapshot_json)
VALUES ('retired-check-scan', 'retired_check_id', @snapshot_json)
"@ -Parameters @{ snapshot_json = $snapshot } -AsNonQuery | Out-Null

        $results = @(Get-CIEMScanResult -ScanRunId 'retired-check-scan')

        $results | Should -HaveCount 1
        $results[0].Check.Id | Should -Be 'retired_check_id'
        $results[0].Check.Title | Should -Be 'Retired Check Title'
        $results[0].Status | Should -Be 'FAIL'
    }
}
