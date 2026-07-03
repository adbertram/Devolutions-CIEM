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

Describe 'Dashboard information architecture' {

    It 'Renders a compact overview, priority work, and collapsed supporting evidence layout without legacy scanner references' {
        $legacyScannerName = 'Pro' + 'wler'
        $script:PageSource | Should -Match "New-UDElement\s+-Tag 'section'\s+-Id 'dashboardOverviewSection'"
        $script:PageSource | Should -Match "New-UDElement\s+-Id 'dashboardPrimaryStateGrid'"
        $script:PageSource | Should -Match "'data-ciem-dashboard-status-metric'\s*=\s*'true'"
        $script:PageSource | Should -Match "New-UDElement\s+-Tag 'section'\s+-Id 'dashboardPriorityWorkSection'"
        $script:PageSource | Should -Match "New-UDElement\s+-Tag 'section'\s+-Id 'dashboardSupportingEvidenceSection'"
        $script:PageSource | Should -Match "New-UDExpansionPanelGroup\s+-Id 'dashboardSupportingEvidencePanelGroup'.*-Type 'Accordion'"
        $script:PageSource | Should -Match "New-UDExpansionPanel\s+-Id 'dashboardChecksAndScansPanel'"
        $script:PageSource | Should -Match "New-UDExpansionPanel\s+-Id 'dashboardIdentityAndPAMPanel'"
        $script:PageSource | Should -Match "New-UDElement\s+-Tag 'section'\s+-Id 'dashboardScanSection'"
        $script:PageSource | Should -Match "New-UDElement\s+-Tag 'section'\s+-Id 'dashboardIdentitySection'"
        $script:PageSource | Should -Match 'Checks & Scans'
        $script:PageSource | Should -Not -Match "\b$legacyScannerName\b"
        $script:PageSource | Should -Match 'Identity Stats'
    }

    It 'Places status first, priority work next, and collapsed supporting evidence last' {
        $overviewIndex = $script:PageSource.IndexOf("dashboardOverviewSection")
        $priorityIndex = $script:PageSource.IndexOf("dashboardPriorityWorkSection")
        $supportingIndex = $script:PageSource.IndexOf("dashboardSupportingEvidenceSection")

        $overviewIndex | Should -BeGreaterThan -1
        $priorityIndex | Should -BeGreaterThan -1
        $supportingIndex | Should -BeGreaterThan -1
        $overviewIndex | Should -BeLessThan $priorityIndex
        $priorityIndex | Should -BeLessThan $supportingIndex
        $script:PageSource | Should -Match 'New-UDExpansionPanelGroup'
    }

    It 'Keeps supporting detail panels collapsed by default' {
        $script:PageSource | Should -Match "New-UDExpansionPanel\s+-Id 'dashboardChecksAndScansPanel'"
        $script:PageSource | Should -Match "New-UDExpansionPanel\s+-Id 'dashboardIdentityAndPAMPanel'"
        $script:PageSource | Should -Not -Match "dashboardChecksAndScansPanel'[\s\S]*?-Active"
        $script:PageSource | Should -Not -Match "dashboardIdentityAndPAMPanel'[\s\S]*?-Active"
    }

    It 'Does not render removed dashboard signal references' {
        foreach ($removedTerm in @(
            ('ex' + 'posure'),
            ('con' + 'nector'),
            ('Get-CIEM' + 'Ex' + 'posure' + 'Change'),
            ('Get-CIEM' + 'Con' + 'nector' + 'PayloadPreview')
        )) {
            $script:PageSource | Should -Not -Match $removedTerm
        }
    }

    It 'Renders Environmental Progress from the report context without route hardcoding' {
        $script:PageSource | Should -Match "New-UDElement\s+-Tag 'section'\s+-Id 'dashboardEnvironmentalProgressSection'"
        $script:PageSource | Should -Match "'data-ciem-environmental-progress'\s*=\s*'true'"
        $script:PageSource | Should -Match "Invoke-CIEMReport\s+-Id 'azure.environmental.progress'"
        $script:PageSource | Should -Match 'Context\.MetricKeys'
        $script:PageSource | Should -Match '''data-ciem-environmental-progress-metric''\s*=\s*\$metricKey'
        $script:PageSource | Should -Match "'data-ciem-environmental-progress-status'\s*=\s*'true'"
        $script:PageSource | Should -Match "'data-ciem-environmental-progress-reports-link'\s*=\s*'true'"
        $script:PageSource | Should -Match 'GetCIEMPSUPageRegistry'
        $script:PageSource | Should -Match 'GetCIEMPSUPageHref'
        $script:PageSource | Should -Not -Match "Invoke-UDRedirect\s+'/ciem/reports'"
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
    It 'Renders the Needs Attention queue inside priority work before supporting evidence' {
        $needsAttentionIndex = $script:PageSource.IndexOf("dashboardNeedsAttentionSection")
        $priorityIndex = $script:PageSource.IndexOf("dashboardPriorityWorkSection")
        $supportingIndex = $script:PageSource.IndexOf("dashboardSupportingEvidenceSection")

        $needsAttentionIndex | Should -BeGreaterThan -1
        $priorityIndex | Should -BeGreaterThan -1
        $supportingIndex | Should -BeGreaterThan -1
        $priorityIndex | Should -BeLessThan $needsAttentionIndex
        $needsAttentionIndex | Should -BeLessThan $supportingIndex
        $script:PageSource | Should -Match 'Get-CIEMDashboardNeedsAttention'
        $script:PageSource | Should -Match "'data-ciem-needs-attention-item'\s*=\s*'true'"
        $script:PageSource | Should -Match "'data-ciem-inspect-identity'\s*=\s*'true'"
        $script:PageSource | Should -Match "'data-ciem-inspect-attack-path'\s*=\s*'true'"
        $script:PageSource | Should -Match 'DrillInUrl'
    }
}

Describe 'Dashboard PAM Implementation Progress' {
    It 'Renders read-only PAM progress in supporting evidence' {
        $progressIndex = $script:PageSource.IndexOf("dashboardPAMProgressSection")
        $supportingIndex = $script:PageSource.IndexOf("dashboardSupportingEvidenceSection")

        $progressIndex | Should -BeGreaterThan -1
        $supportingIndex | Should -BeGreaterThan -1
        $supportingIndex | Should -BeLessThan $progressIndex
        $script:PageSource | Should -Match 'PAM Implementation Progress'
        $script:PageSource | Should -Match 'Get-CIEMPAMProgressSummary'
        $script:PageSource | Should -Match "'data-ciem-pam-progress-stage'\s*=\s*'true'"
        $script:PageSource | Should -Match "'data-ciem-pam-progress-candidate'\s*=\s*'true'"
        $script:PageSource | Should -Match 'No PAM candidates are mapped yet'
    }
}

Describe 'Dashboard Scan Efficiency' {
    It 'Renders scan efficiency instrumentation in supporting evidence' {
        $efficiencyIndex = $script:PageSource.IndexOf("dashboardScanEfficiencySection")
        $supportingIndex = $script:PageSource.IndexOf("dashboardSupportingEvidenceSection")

        $efficiencyIndex | Should -BeGreaterThan -1
        $supportingIndex | Should -BeGreaterThan -1
        $supportingIndex | Should -BeLessThan $efficiencyIndex
        $script:PageSource | Should -Match 'Scan Efficiency'
        $script:PageSource | Should -Match 'Get-CIEMScanEfficiencySummary'
        $script:PageSource | Should -Match "'data-ciem-scan-efficiency-metric'\s*=\s*'true'"
        $script:PageSource | Should -Match "'data-ciem-scan-efficiency-run'\s*=\s*'true'"
        $script:PageSource | Should -Match 'Discovery Phase Timing'
        $script:PageSource | Should -Match 'LatestDiscoveryPhaseMetrics'
        $script:PageSource | Should -Match "'data-ciem-discovery-phase-metric'\s*=\s*'true'"
    }
}
