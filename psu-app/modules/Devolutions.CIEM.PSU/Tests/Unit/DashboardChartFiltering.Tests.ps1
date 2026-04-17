BeforeAll {
    $script:PageFile = Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMDashboardPage.ps1'
    $script:PageSource = Get-Content -Path $script:PageFile -Raw
}

Describe 'Dashboard chart provider filtering' {

    It 'Filters provider chart results using top-level Provider, not nested Check.Provider' {
        # After line 82-92 transforms raw results into flat PSCustomObjects,
        # the chart loop (foreach $chartProvider) must filter on $_.Provider.
        # Using $_.Check.Provider on the flat objects would always be $null.
        #
        # Match the specific chart-filtering pattern: Where-Object comparing to $chartProvider
        $script:PageSource | Should -Not -Match 'Where-Object\s*\{[^}]*\$_\.Check\.Provider\s+-eq\s+\$chartProvider'
    }

    It 'Uses $_.Provider for provider-based filtering of scan results' {
        $script:PageSource | Should -Match '\$_\.Provider\s+-eq\s+\$chartProvider'
    }
}

Describe 'Dashboard last discovery ownership' {

    It 'Does not render a page-local Last Discovery summary' {
        $script:PageSource | Should -Not -Match 'lastDiscoverySummary'
    }

    It 'Does not query discovery runs from the Dashboard page' {
        $script:PageSource | Should -Not -Match "Get-CIEMAzureDiscoveryRun\s+-Status 'Completed'\s+-Last 1"
    }
}
