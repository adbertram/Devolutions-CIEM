BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    # Read source for structural assertions
    $script:ConnectSource = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Public' 'Connect-CIEMAzure.ps1') -Raw
}

Describe 'Connect-CIEMAzure' {

    Context 'Az cmdlets removed from source' {
        It 'Does not contain Clear-AzContext' {
            $script:ConnectSource | Should -Not -Match 'Clear-AzContext'
        }

        It 'Does not contain Connect-AzAccount' {
            $script:ConnectSource | Should -Not -Match 'Connect-AzAccount'
        }

        It 'Does not contain Get-AzContext' {
            $script:ConnectSource | Should -Not -Match 'Get-AzContext'
        }

        It 'Does not contain Get-AzSubscription' {
            $script:ConnectSource | Should -Not -Match 'Get-AzSubscription'
        }
    }

    Context 'MSAL dependency removed from source' {
        It 'Does not contain Microsoft.Identity.Client' {
            $script:ConnectSource | Should -Not -Match 'Microsoft\.Identity\.Client'
        }
    }

    Context 'REST replacement present in source' {
        It 'Calls ARM subscriptions API' {
            $script:ConnectSource | Should -Match 'management\.azure\.com/subscriptions\?api-version='
        }

        It 'Filters subscriptions to Enabled state' {
            $script:ConnectSource | Should -Match "state.*-eq.*Enabled|Enabled.*state"
        }
    }

    Context 'Command structure' {
        It 'Connect-CIEMAzure is a public command' {
            Get-Command -Name Connect-CIEMAzure -Module Devolutions.CIEM -ErrorAction Stop |
                Should -Not -BeNullOrEmpty
        }

        It 'Has OutputType PSCustomObject' {
            $script:ConnectSource | Should -Match '\[OutputType\(\[PSCustomObject\]\)\]'
        }
    }
}
