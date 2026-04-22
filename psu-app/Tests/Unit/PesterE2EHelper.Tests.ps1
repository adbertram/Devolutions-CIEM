Describe 'PesterE2EHelper environment routing' {
    BeforeAll {
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
        $script:helperSource = Get-Content (Join-Path $projectRoot 'Tests/E2E/PesterE2EHelper.ps1') -Raw
    }

    It 'accepts local and azure as target environments' {
        $script:helperSource | Should -Match "\[ValidateSet\('local', 'azure'\)\]"
    }

    It 'passes the selected environment to Invoke-TestCommand' {
        $script:helperSource | Should -Match 'Invoke-TestCommand[\s\S]+-Environment \$script:PesterE2EEnvironment'
    }

    It 'connects to Azure without the local PSU switch' {
        $script:helperSource | Should -Match "else \{[\s\S]+Connect-PSU \| Out-Null"
    }
}
