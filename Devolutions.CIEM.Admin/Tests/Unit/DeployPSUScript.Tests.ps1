BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts/deploy-psu.sh'
    $script:ScriptSource = Get-Content -Path $script:ScriptPath -Raw
}

Describe 'scripts/deploy-psu.sh' {
    It 'delegates Azure PSU instance deployment to Devolutions.CIEM.Admin' {
        $script:ScriptSource | Should -Match 'Deploy-CIEMPSUInstance'
        $script:ScriptSource | Should -Match 'scripts/lib/log\.sh'
        $script:ScriptSource | Should -Not -Match 'az deployment group create'
        $script:ScriptSource | Should -Not -Match 'curl -s -o /dev/null'
    }
}
