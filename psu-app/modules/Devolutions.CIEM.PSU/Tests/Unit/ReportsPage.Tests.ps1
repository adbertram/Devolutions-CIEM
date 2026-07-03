BeforeAll {
    $script:PagesRoot = Join-Path $PSScriptRoot '..' '..' 'Pages'
    $script:AppFactoryPath = Join-Path $PSScriptRoot '..' '..' 'Public' 'New-DevolutionsCIEMApp.ps1'
    $script:NavigationPath = Join-Path $script:PagesRoot 'New-CIEMNavigation.ps1'
    $script:ReportsPagePath = Join-Path $script:PagesRoot 'New-CIEMReportsPage.ps1'
    $script:PageRegistryPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'pages.json'

    $script:AppFactoryContent = Get-Content -Path $script:AppFactoryPath -Raw
    $script:NavigationContent = Get-Content -Path $script:NavigationPath -Raw
    $script:PageRegistry = @(Get-Content -Path $script:PageRegistryPath -Raw | ConvertFrom-Json -Depth 10)
}

Describe 'Reports PSU page registration' {
    It 'Registers the Reports page in the CIEM page registry' {
        $reportsPage = $script:PageRegistry | Where-Object name -eq 'Reports'

        $reportsPage | Should -Not -BeNullOrEmpty
        $reportsPage.route | Should -Be '/reports'
        $reportsPage.factory | Should -Be 'New-CIEMReportsPage'
    }

    It 'Builds Reports sidebar navigation from the page registry' {
        $script:NavigationContent | Should -Match 'GetCIEMPSUPageRegistry'
        $script:NavigationContent | Should -Match 'GetCIEMPSUPageHref'
        $script:AppFactoryContent | Should -Match 'GetCIEMPSUPageRegistry'
    }

    It 'Defines the Reports page at the reports route' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match "New-UDPage\s+-Name 'Reports'\s+-Url '/ciem/reports'"
    }

    It 'Loads report definitions through the public report command' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match 'Devolutions\.CIEM\\Get-CIEMReport'
    }

    It 'Invokes the selected report through the public report command' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match 'Devolutions\.CIEM\\Invoke-CIEMReport'
    }

    It 'Provides an on-demand report generation action' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match "New-UDButton\s+-Id 'generateReportBtn'\s+-Text 'Generate Report'"
        $reportsPageContent | Should -Match 'Devolutions\.CIEM\\Invoke-CIEMReport'
        $reportsPageContent | Should -Match '\$Page:SelectedReportParameters'
        $reportsPageContent | Should -Match 'Invoke-CIEMReport\s+-InputObject\s+\$selectedReport\s+-Parameter\s+\$parameters'
        $reportsPageContent | Should -Match "Sync-UDElement\s+-Id 'ciemReportsPanel'"
    }

    It 'Renders completed discovery run selection for past report views' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match "Devolutions\.CIEM\\Get-CIEMAzureDiscoveryRun\s+-Status 'Completed'\s+-Last"
        $reportsPageContent | Should -Match 'New-UDSelect\s+-Id \(\[string\]\$parameter\.selectorId\)'
        $reportsPageContent | Should -Match '\$parameter\.selectorId'
        $reportsPageContent | Should -Match 'data-ciem-report-history'
    }

    It 'Renders environmental progress pair selection from the public option command' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match 'Devolutions\.CIEM\\Get-CIEMEnvironmentalProgressEvidencePairOption'
        $reportsPageContent | Should -Match 'EnvironmentalProgressEvidencePairs'
        $reportsPageContent | Should -Match '\$parameter\.selectorId'
    }

    It 'Renders report context, summary, and result table regions' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match 'data-ciem-report-result'
        $reportsPageContent | Should -Match 'data-ciem-report-context'
        $reportsPageContent | Should -Match 'ContextChipKeys'
        $reportsPageContent | Should -Match 'data-ciem-report-context-chip'
        $reportsPageContent | Should -Match 'data-ciem-report-summary'
        $reportsPageContent | Should -Match 'data-ciem-report-result-table'
    }

    It 'Uses report-specific summary and empty-state metadata from the report registry' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match '\$selectedReport\.StatusSummary'
        $reportsPageContent | Should -Match '\$selectedReport\.EmptyState'
        $reportsPageContent | Should -Match 'StatusMessage'
        $reportsPageContent | Should -Not -Match "@\\('Collected', 'Partial', 'Missing', 'Skipped'\\)"
    }
}
