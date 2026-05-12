BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts/reinstall-ciem-psu-module.sh'
    $script:ScriptSource = Get-Content -Path $script:ScriptPath -Raw
}

Describe 'scripts/reinstall-ciem-psu-module.sh' {
    It 'exists under the project scripts directory' {
        $script:ScriptPath | Should -Exist
    }

    It 'removes CIEM before deploying the existing Gallery module' {
        $removeIndex = $script:ScriptSource.IndexOf('Remove-CIEMPSUModule @removeParams')
        $deployIndex = $script:ScriptSource.IndexOf('Deploy-PSUModule @deployParams')

        $removeIndex | Should -BeGreaterOrEqual 0
        $deployIndex | Should -BeGreaterThan $removeIndex
        $script:ScriptSource | Should -Match 'scripts/lib/log\.sh'
        $script:ScriptSource | Should -Not -Match 'InstallPublishedVersion'
        $script:ScriptSource | Should -Not -Match 'Publish-PSUModule'
        $script:ScriptSource | Should -Not -Match 'NuGetApiKey'
        $script:ScriptSource | Should -Not -Match 'Publish-PSResource'
    }

    It 'passes the target environment through to Deploy-PSUModule' {
        $script:ScriptSource | Should -Match '\$deployParams\.Environment\s*=\s*\$Environment|Environment\s*=\s*\$Environment'
    }

    It 'does not request an app restart outside the Gallery module install process' {
        $script:ScriptSource | Should -Match 'SkipAppRestart\s*=\s*\$true'
        $script:ScriptSource | Should -Not -Match 'Restart-CIEMPSUApp'
        $script:ScriptSource | Should -Not -Match 'Restart-PSUApp'
    }

    It 'defaults to the local PSU target unless another environment is specified' {
        $script:ScriptSource | Should -Match 'ENVIRONMENT="local"'
        $script:ScriptSource | Should -Match 'ValidateSet\("local", "azure"\)'
    }

    It 'checks the published Gallery version before removing CIEM for a validated reinstall' {
        $preflightIndex = $script:ScriptSource.IndexOf('Find-Module -Name $moduleName')
        $removeIndex = $script:ScriptSource.IndexOf('Remove-CIEMPSUModule @removeParams')

        $preflightIndex | Should -BeGreaterOrEqual 0
        $removeIndex | Should -BeGreaterThan $preflightIndex
        $script:ScriptSource | Should -Match 'CIEM_VALIDATE_DEPLOYMENT="\$VALIDATE_DEPLOYMENT"'
        $script:ScriptSource | Should -Match 'PowerShell Gallery'
        $script:ScriptSource | Should -Match 'local validation requires'
    }
}
