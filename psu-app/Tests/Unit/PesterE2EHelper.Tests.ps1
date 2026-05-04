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

    It 'accepts WarningOutput as a terminal successful PSU job status' {
        $script:helperSource | Should -Match "'Completed', 'Warning', 'WarningOutput'"
    }

    It 'runs remote commands with ErrorActionPreference Stop' {
        $script:helperSource | Should -Match "\`$ErrorActionPreference = 'Stop'"
    }

    It 'defines an Azure minimum command timeout for slow App Service runs' {
        $script:helperSource | Should -Match "\`$script:PesterE2EAzureCommandTimeoutSeconds = 300"
        $script:helperSource | Should -Match 'GetPesterE2ECommandTimeout'
    }

    It 'defines an Azure minimum long-running timeout for full discovery runs' {
        $script:helperSource | Should -Match "\`$script:PesterE2EAzureLongRunningTimeoutSeconds = 3600"
        $script:helperSource | Should -Match 'GetPesterE2ELongRunningTimeout'
    }
}
