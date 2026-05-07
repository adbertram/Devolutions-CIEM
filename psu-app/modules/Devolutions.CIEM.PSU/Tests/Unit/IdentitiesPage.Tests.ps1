BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMIdentitiesPage.ps1') -Raw
}

Describe 'Identities page 1080p grid usability' {
    It 'does not expose unsupported AWS identity summary selection' {
        $script:PageContent | Should -Match "New-UDSelect\s+-Id 'identitiesProviderSelect'"
        $script:PageContent | Should -Match "New-UDSelectOption -Name 'Azure' -Value 'Azure'"
        $script:PageContent | Should -Not -Match "New-UDSelectOption -Name 'AWS' -Value 'AWS'"
    }

    It 'keeps the top-level grid focused on identity summary columns' {
        $gridStart = $script:PageContent.IndexOf('New-UDDataGrid -LoadRows')
        $gridStart | Should -BeGreaterThan -1
        $detailStart = $script:PageContent.IndexOf('-LoadDetailContent', $gridStart)
        $detailStart | Should -BeGreaterThan $gridStart
        $topGrid = $script:PageContent.Substring($gridStart, $detailStart - $gridStart)

        $topGrid | Should -Match "New-UDDataGridColumn -Field 'objectId' -HeaderName 'Object ID' -Width 240"
        $topGrid | Should -Not -Match "New-UDDataGridColumn -Field 'targetCount'"
        $topGrid | Should -Not -Match "New-UDDataGridColumn -Field 'accessLevel'"
        $topGrid | Should -Match "-Pagination -PageSize 10 -ShowQuickFilter"
    }
}
