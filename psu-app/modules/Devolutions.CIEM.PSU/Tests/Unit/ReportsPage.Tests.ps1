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

    It 'Renders report context, summary, and result table regions' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match 'data-ciem-report-result'
        $reportsPageContent | Should -Match 'data-ciem-report-context'
        $reportsPageContent | Should -Match 'data-ciem-report-summary'
        $reportsPageContent | Should -Match 'data-ciem-report-result-table'
    }

    It 'Uses report-specific summary and empty-state metadata from the report registry' {
        $script:ReportsPagePath | Should -Exist
        $reportsPageContent = Get-Content -Path $script:ReportsPagePath -Raw
        $reportsPageContent | Should -Match '\$selectedReport\.StatusSummary'
        $reportsPageContent | Should -Match '\$selectedReport\.EmptyState'
        $reportsPageContent | Should -Not -Match "@\\('Collected', 'Partial', 'Missing', 'Skipped'\\)"
    }
}
