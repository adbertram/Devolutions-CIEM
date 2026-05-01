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

Describe 'Dashboard section layout' {

    It 'Renders separate checks and scans and identity stats sections without legacy scanner references' {
        $legacyScannerName = 'Pro' + 'wler'
        $script:PageSource | Should -Match 'New-UDExpansionPanelGroup'
        $script:PageSource | Should -Match "New-UDExpansionPanelGroup\s+-Id 'dashboardSectionPanels'\s+-Type 'Expandable'"
        $script:PageSource | Should -Match "New-UDExpansionPanel\s+-Id 'dashboardScanPanel'"
        $script:PageSource | Should -Match "New-UDExpansionPanel\s+-Id 'dashboardIdentityPanel'"
        $script:PageSource | Should -Match "New-UDElement\s+-Tag 'section'\s+-Id 'dashboardScanSection'"
        $script:PageSource | Should -Match "New-UDElement\s+-Tag 'section'\s+-Id 'dashboardIdentitySection'"
        $script:PageSource | Should -Match "'data-hideable'\s*=\s*'true'"
        $script:PageSource | Should -Match 'Checks & Scans'
        $script:PageSource | Should -Not -Match "\b$legacyScannerName\b"
        $script:PageSource | Should -Match 'Identity Stats'
    }

    It 'Starts both dashboard expansion panels expanded' {
        $scanPanelPattern = "New-UDExpansionPanel\s+-Id 'dashboardScanPanel'(?s).*?-Active"
        $identityPanelPattern = "New-UDExpansionPanel\s+-Id 'dashboardIdentityPanel'(?s).*?-Active"
        $script:PageSource | Should -Match $scanPanelPattern
        $script:PageSource | Should -Match $identityPanelPattern
    }

    It 'Calculates identity stats from identity data tables' {
        $script:PageSource | Should -Match 'graph_nodes'
        $script:PageSource | Should -Match 'azure_effective_role_assignments'
        $script:PageSource | Should -Match 'EntraUser'
        $script:PageSource | Should -Match 'EntraServicePrincipal'
        $script:PageSource | Should -Match 'EntraGroup'
    }
}
