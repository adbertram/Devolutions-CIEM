Describe 'Playwright PSU helper command execution' {
    BeforeAll {
        $script:HelperSource = Get-Content -Path (Join-Path $PSScriptRoot '..' '..' 'ui' 'e2e' '_utils' 'psu-helpers.js') -Raw
    }

    It 'does not send ScriptContent through the PSU REST query string' {
        $script:HelperSource | Should -Not -Match '\?ScriptContent='
        $script:HelperSource | Should -Not -Match 'searchParams\.append\(''ScriptContent'''
    }

    It 'uses Invoke-PSUScript parameters for executor script content' {
        $script:HelperSource | Should -Match 'Invoke-PSUScript'
        $script:HelperSource | Should -Match '-Parameters'
        $script:HelperSource | Should -Match 'ScriptContent'
    }
}
