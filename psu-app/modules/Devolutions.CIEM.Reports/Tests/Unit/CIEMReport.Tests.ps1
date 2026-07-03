BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'CIEM Reports' {

    Context 'Report classes' {
        It 'CIEMReport stores the registry definition fields used by the generic invoker' {
            $report = InModuleScope Devolutions.CIEM { [CIEMReport]::new() }

            $props = $report.PSObject.Properties.Name
            $props | Should -Contain 'Id'
            $props | Should -Contain 'Provider'
            $props | Should -Contain 'Category'
            $props | Should -Contain 'Title'
            $props | Should -Contain 'Description'
            $props | Should -Contain 'ExecutorName'
            $props | Should -Contain 'Columns'
            $props | Should -Contain 'Visuals'
            $props | Should -Contain 'Parameters'
            $props | Should -Contain 'StatusSummary'
            $props | Should -Contain 'EmptyState'
        }

        It 'CIEMReportResult stores the rendered report payload fields returned to the UI' {
            $result = InModuleScope Devolutions.CIEM { [CIEMReportResult]::new() }

            $props = $result.PSObject.Properties.Name
            $props | Should -Contain 'ReportId'
            $props | Should -Contain 'Title'
            $props | Should -Contain 'GeneratedAt'
            $props | Should -Contain 'Columns'
            $props | Should -Contain 'Rows'
            $props | Should -Contain 'Visuals'
            $props | Should -Contain 'Context'
        }

    }

    Context 'Get-CIEMReport' {
        It 'Loads a strict report registry with unique ids, resolvable executors, and known visuals' {
            InModuleScope Devolutions.CIEM {
                TestCIEMReportRegistry | Should -BeTrue
                $entries = @(GetCIEMReportRegistry)
                $entries | Should -Not -BeNullOrEmpty
                ($entries.id | Select-Object -Unique) | Should -HaveCount $entries.Count

                foreach ($entry in $entries) {
                    Get-Command -Name $entry.executorName -CommandType Function -ErrorAction Stop | Should -Not -BeNullOrEmpty
                    foreach ($visual in @($entry.visuals)) {
                        $visual | Should -BeIn @('coverage-status-summary', 'coverage-row-table')
                    }
                }
            }
        }

        It 'Returns CIEMReport definitions from the registry' {
            $reports = @(Get-CIEMReport)

            $reports | Should -Not -BeNullOrEmpty
            $reports | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMReport' }
            $reports.Id | Should -Contain 'azure.discovery.coverage'
        }

        It 'Returns the Azure discovery coverage definition by Id' {
            $report = Get-CIEMReport -Id 'azure.discovery.coverage'

            $report.GetType().Name | Should -Be 'CIEMReport'
            $report.Id | Should -Be 'azure.discovery.coverage'
            $report.Provider | Should -Be 'Azure'
            $report.Category | Should -Be 'Discovery'
            $report.Title | Should -Be 'Azure Discovery Coverage'
            $report.ExecutorName | Should -Be 'GetCIEMAzureDiscoveryCoverageReportData'
            $report.Columns | Should -Contain 'Area'
            $report.Columns | Should -Contain 'Status'
            $report.Visuals | Should -Contain 'coverage-status-summary'
            $report.Parameters[0].name | Should -Be 'RunId'
            $report.Parameters[0].selectorId | Should -Be 'reportRunSelector'
            $report.Parameters[0].label | Should -Be 'Discovery run'
            $report.Parameters[0].optionSource | Should -Be 'CompletedDiscoveryRuns'
            $report.Parameters[0].allowEmpty | Should -BeFalse
            $report.StatusSummary.Status | Should -Contain 'Collected'
            $report.EmptyState | Should -Be 'No Azure discovery coverage rows are available.'
        }

        It 'Returns the Azure environmental progress definition with parameter object metadata' {
            $report = Get-CIEMReport -Id 'azure.environmental.progress'

            $report.GetType().Name | Should -Be 'CIEMReport'
            $report.Id | Should -Be 'azure.environmental.progress'
            $report.ExecutorName | Should -Be 'GetCIEMEnvironmentalProgressReportData'
            $report.Columns | Should -Contain 'SignalKey'
            $report.Columns | Should -Contain 'BaselineDiscoveryRunId'
            $report.Parameters[0].name | Should -Be 'EvidencePairId'
            $report.Parameters[0].selectorId | Should -Be 'reportEvidencePairSelector'
            $report.Parameters[0].optionSource | Should -Be 'EnvironmentalProgressEvidencePairs'
            $report.Parameters[0].allowEmpty | Should -BeTrue
            $report.StatusSummary.Status | Should -Contain 'Fixed'
            $report.StatusSummary.Status | Should -Contain 'Remaining'
            $report.StatusSummary.Status | Should -Contain 'New'
        }

        It 'Filters reports by provider' {
            $reports = @(Get-CIEMReport -Provider 'Azure')

            $reports | Should -Not -BeNullOrEmpty
            $reports.Provider | ForEach-Object { $_ | Should -Be 'Azure' }
        }

        It 'Filters reports by category' {
            $reports = @(Get-CIEMReport -Category 'Discovery')

            $reports | Should -Not -BeNullOrEmpty
            $reports.Category | ForEach-Object { $_ | Should -Be 'Discovery' }
        }

        It 'Throws when the requested report definition is not registered' {
            { Get-CIEMReport -Id 'does.not.exist' } | Should -Throw "CIEM report 'does.not.exist' was not found."
        }
    }

    Context 'Invoke-CIEMReport' {
        It 'Throws when the requested report definition is not registered' {
            { Invoke-CIEMReport -Id 'does.not.exist' } | Should -Throw "CIEM report 'does.not.exist' was not found."
        }

        It 'Throws when the report executor omits a configured result column' {
            Mock -ModuleName Devolutions.CIEM GetCIEMAzureDiscoveryCoverageReportData {
                [pscustomobject]@{
                    Rows = @(
                        [pscustomobject]@{
                            Area = 'ARM resources'
                        }
                    )
                    Context = @{}
                }
            }

            { Invoke-CIEMReport -Id 'azure.discovery.coverage' -Parameter @{ RunId = 1 } } |
                Should -Throw "*row is missing configured column 'SourceApi'*"
        }

        It 'Rejects supplied parameters that the selected report does not declare' {
            { Invoke-CIEMReport -Id 'azure.discovery.coverage' -Parameter @{ Unexpected = 'x' } } |
                Should -Throw "*does not declare parameter 'Unexpected'*"
        }
    }

}
