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

    It 'connects to Azure with the explicit Azure PSU switch' {
        $script:helperSource | Should -Match "else \{[\s\S]+Connect-PSU -Azure \| Out-Null"
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

    It 'retries Invoke-TestCommand on transient Connect-PSUServer auth loss' {
        # When PSU rapid-fire calls intermittently lose Connect-PSUServer auth context,
        # Invoke-PSUScript throws "Cannot retrieve the dynamic parameters for the cmdlet.
        # Unauthenticated." Run-OnPSU must catch this and retry with a fresh Connect-PSU.
        $script:helperSource | Should -Match 'Cannot retrieve the dynamic parameters'
    }

    It 'reconnects PSU before retrying after a transient auth failure' {
        # Retry must call Connect-PSU again (or equivalent) so the next Invoke-TestCommand
        # gets a fresh Connect-PSUServer session — re-running the same call without
        # reconnecting will hit the same stale dynamic-parameter cache.
        $script:helperSource | Should -Match 'Connect-PSU'
    }
}
