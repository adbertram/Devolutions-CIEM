BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMScanPage.ps1') -Raw
}

Describe 'Scan page selection state' {
    It 'clears stale selected check IDs before rendering the selection grid' {
        $script:PageContent | Should -Match 'New-UDPage[\s\S]*\$Session:SelectedCheckIds\s*=\s*@\(\)[\s\S]*New-UDCard\s+-Title\s+''Check Selection'''
    }

    It 'uses a literal PSU cache key inside the Start Scan event handler' {
        $script:PageContent | Should -Not -Match '\$script:ScanConfigCacheKey'
        $script:PageContent | Should -Match "Set-PSUCache -Key 'CIEM:ScanConfig'"
    }

    It 'captures info modal row fields before the nested click handler executes' {
        $script:PageContent | Should -Match '\$checkTitle\s*=\s*\[string\]\$EventData\.title'
        $script:PageContent | Should -Match '\$checkSeverity\s*=\s*\[string\]\$EventData\.severity'

        $infoColumnStart = $script:PageContent.IndexOf("New-UDDataGridColumn -Field 'info'")
        $infoColumnStart | Should -BeGreaterThan -1
        $severityColumnStart = $script:PageContent.IndexOf("New-UDDataGridColumn -Field 'severity'", $infoColumnStart)
        $severityColumnStart | Should -BeGreaterThan $infoColumnStart
        $infoColumn = $script:PageContent.Substring($infoColumnStart, $severityColumnStart - $infoColumnStart)

        $infoClickStart = $infoColumn.IndexOf('-OnClick {')
        $infoClickStart | Should -BeGreaterThan -1
        $infoClickBlock = $infoColumn.Substring($infoClickStart)
        $infoClickBlock | Should -Not -Match '\$EventData\.'
        $infoClickBlock | Should -Match '\$checkTitle'
        $infoClickBlock | Should -Match '\$checkSeverity'
    }
}
