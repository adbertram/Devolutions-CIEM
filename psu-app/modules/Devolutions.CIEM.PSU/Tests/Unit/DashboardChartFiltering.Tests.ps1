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

Describe 'Dashboard Needs Attention queue' {
    It 'Renders the Needs Attention queue before secondary dashboard sections' {
        $needsAttentionIndex = $script:PageSource.IndexOf("dashboardNeedsAttentionSection")
        $sectionPanelsIndex = $script:PageSource.IndexOf("dashboardSectionPanels")

        $needsAttentionIndex | Should -BeGreaterThan -1
        $sectionPanelsIndex | Should -BeGreaterThan -1
        $needsAttentionIndex | Should -BeLessThan $sectionPanelsIndex
        $script:PageSource | Should -Match 'Get-CIEMDashboardNeedsAttention'
        $script:PageSource | Should -Match "'data-ciem-needs-attention-item'\s*=\s*'true'"
        $script:PageSource | Should -Match "'data-ciem-inspect-identity'\s*=\s*'true'"
        $script:PageSource | Should -Match "'data-ciem-inspect-attack-path'\s*=\s*'true'"
    }
}

Describe 'Dashboard Exposure Changes queue' {
    It 'Renders local exposure-change records before secondary dashboard sections' {
        $exposureChangesIndex = $script:PageSource.IndexOf("dashboardExposureChangesSection")
        $sectionPanelsIndex = $script:PageSource.IndexOf("dashboardSectionPanels")

        $exposureChangesIndex | Should -BeGreaterThan -1
        $sectionPanelsIndex | Should -BeGreaterThan -1
        $exposureChangesIndex | Should -BeLessThan $sectionPanelsIndex
        $script:PageSource | Should -Match 'Exposure Changes'
        $script:PageSource | Should -Match 'Get-CIEMExposureChange'
        $script:PageSource | Should -Match "'data-ciem-exposure-change-item'\s*=\s*'true'"
        $script:PageSource | Should -Match 'Payload delivery is not enabled'
    }
}

Describe 'Dashboard Connector Payload Previews' {
    It 'Renders preview-only connector payloads before secondary dashboard sections' {
        $previewIndex = $script:PageSource.IndexOf("dashboardConnectorPayloadPreviewSection")
        $sectionPanelsIndex = $script:PageSource.IndexOf("dashboardSectionPanels")

        $previewIndex | Should -BeGreaterThan -1
        $sectionPanelsIndex | Should -BeGreaterThan -1
        $previewIndex | Should -BeLessThan $sectionPanelsIndex
        $script:PageSource | Should -Match 'Connector Payload Previews'
        $script:PageSource | Should -Match 'Get-CIEMConnectorPayloadPreview'
        $script:PageSource | Should -Match "'data-ciem-connector-payload-preview-item'\s*=\s*'true'"
        $script:PageSource | Should -Match 'No outbound target is configured or contacted'
    }
}

Describe 'Dashboard PAM Implementation Progress' {
    It 'Renders read-only PAM progress before secondary dashboard sections' {
        $progressIndex = $script:PageSource.IndexOf("dashboardPAMProgressSection")
        $sectionPanelsIndex = $script:PageSource.IndexOf("dashboardSectionPanels")

        $progressIndex | Should -BeGreaterThan -1
        $sectionPanelsIndex | Should -BeGreaterThan -1
        $progressIndex | Should -BeLessThan $sectionPanelsIndex
        $script:PageSource | Should -Match 'PAM Implementation Progress'
        $script:PageSource | Should -Match 'Get-CIEMPAMProgressSummary'
        $script:PageSource | Should -Match "'data-ciem-pam-progress-stage'\s*=\s*'true'"
        $script:PageSource | Should -Match "'data-ciem-pam-progress-candidate'\s*=\s*'true'"
        $script:PageSource | Should -Match 'No PAM candidates are mapped yet'
    }
}

Describe 'Dashboard Scan Efficiency' {
    It 'Renders scan efficiency instrumentation before secondary dashboard sections' {
        $efficiencyIndex = $script:PageSource.IndexOf("dashboardScanEfficiencySection")
        $sectionPanelsIndex = $script:PageSource.IndexOf("dashboardSectionPanels")

        $efficiencyIndex | Should -BeGreaterThan -1
        $sectionPanelsIndex | Should -BeGreaterThan -1
        $efficiencyIndex | Should -BeLessThan $sectionPanelsIndex
        $script:PageSource | Should -Match 'Scan Efficiency'
        $script:PageSource | Should -Match 'Get-CIEMScanEfficiencySummary'
        $script:PageSource | Should -Match "'data-ciem-scan-efficiency-metric'\s*=\s*'true'"
        $script:PageSource | Should -Match "'data-ciem-scan-efficiency-run'\s*=\s*'true'"
    }
}
