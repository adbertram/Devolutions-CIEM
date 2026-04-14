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

    Context 'Data-driven token acquisition' {
        It 'Defines tokenScopes data array' {
            $script:ConnectSource | Should -Match '\$tokenScopes\s*='
        }

        It 'Does not hardcode scope URLs in per-method switch branches' {
            # Extract the switch block content (between 'switch ($profile.Method)' and the closing shared loop)
            # Scope URLs should only appear in the $tokenScopes data array, not in the switch body
            $switchMatch = [regex]::Match($script:ConnectSource, 'switch \(\$profile\.Method\) \{(.+?)\n    \}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($switchMatch.Success) {
                $switchBody = $switchMatch.Groups[1].Value
                # No hardcoded .default scope URLs inside the switch block
                $switchBody | Should -Not -Match 'management\.azure\.com/\.default'
                $switchBody | Should -Not -Match 'graph\.microsoft\.com/\.default'
                $switchBody | Should -Not -Match 'vault\.azure\.net/\.default'
            }
        }

        It 'Uses shared token acquisition loop' {
            $script:ConnectSource | Should -Match 'foreach \(\$scope in \$tokenScopes\)'
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

        It 'does not expose the module-defined CIEMAzureAuthenticationProfile class in its public parameter type' {
            $command = Get-Command -Name Connect-CIEMAzure -Module Devolutions.CIEM -ErrorAction Stop
            $command.Parameters['AuthenticationProfile'].ParameterType.FullName | Should -Be 'System.Object'
        }

        It 'does not reference CIEMAzureAuthenticationProfile in the public parameter declaration' {
            $script:ConnectSource | Should -Not -Match '\[CIEMAzureAuthenticationProfile\]\$AuthenticationProfile'
        }
    }
}
