BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMAttackPathsPage.ps1') -Raw
}

Describe 'Attack Paths page refresh action' {
    It 'Displays a refresh button on the Attack Paths page' {
        $script:PageContent | Should -Match "New-UDButton[\s\S]*-Id\s+'refreshAttackPathsBtn'"
        $script:PageContent | Should -Match "-Text\s+'Refresh Attack Paths'"
    }

    It 'Materializes attack paths and reloads the Attack Paths panel after refresh' {
        $script:PageContent | Should -Match 'Devolutions\.CIEM\\Update-CIEMAttackPath\s+-PassThru'
        $script:PageContent | Should -Match "Sync-UDElement\s+-Id\s+'attackPathsPanel'"
        $script:PageContent | Should -Match 'Show-UDToast[\s\S]*Attack paths refreshed'
    }
}
