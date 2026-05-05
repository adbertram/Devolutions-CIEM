BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts/remove-psu.ps1'
    $script:ScriptSource = Get-Content -Path $script:ScriptPath -Raw
}

Describe 'scripts/remove-psu.ps1' {
    It 'exists under the project scripts directory' {
        $script:ScriptPath | Should -Exist
    }

    It 'is a thin wrapper around Remove-CIEMPSUModule' {
        $script:ScriptSource | Should -Match 'Import-Module\s+\$adminManifest'
        $script:ScriptSource | Should -Match 'Remove-CIEMPSUModule\s+@removeParams'
        $script:ScriptSource | Should -Not -Match 'function\s+Get-CIEMPSUScriptRemovalModel'
        $script:ScriptSource | Should -Not -Match 'function\s+Invoke-CIEMPSURemoval'
    }
}
