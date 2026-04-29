BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMScanPage.ps1') -Raw
}

Describe 'Scan page selection state' {
    It 'clears stale selected check IDs before rendering the selection grid' {
        $script:PageContent | Should -Match 'New-UDPage[\s\S]*\$Session:SelectedCheckIds\s*=\s*@\(\)[\s\S]*New-UDCard\s+-Title\s+''Check Selection'''
    }
}
