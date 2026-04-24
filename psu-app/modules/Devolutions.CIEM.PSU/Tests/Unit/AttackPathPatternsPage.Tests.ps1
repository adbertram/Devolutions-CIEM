BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMAttackPathPatternsPage.ps1') -Raw
}

Describe 'Attack Path Patterns page row details' {
    It 'Moves pattern descriptions out of grid columns and into expanded row details' {
        $script:PageContent | Should -Not -Match "New-UDDataGridColumn\s+-Field\s+'description'"
        $script:PageContent | Should -Match "-LoadDetailContent\s+\{"
        $script:PageContent | Should -Match "'data-ciem-attack-path-pattern-description'\s*=\s*'true'"
    }
}
