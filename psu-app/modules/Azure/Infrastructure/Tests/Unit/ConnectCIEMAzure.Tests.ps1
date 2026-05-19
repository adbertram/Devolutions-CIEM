BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Read source for structural assertions
    $script:ConnectSource = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Public' 'Connect-CIEMAzure.ps1') -Raw
}

Describe 'Connect-CIEMAzure' {
    BeforeEach {
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMProvider {
            [pscustomobject]@{
                Id             = 'provider-azure'
                ResourceFilter = @('sub-enabled')
            }
        }
    }

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
            $switchMatch.Success | Should -BeTrue
            $switchBody = $switchMatch.Groups[1].Value
            # No hardcoded .default scope URLs inside the switch block
            $switchBody | Should -Not -Match 'management\.azure\.com/\.default'
            $switchBody | Should -Not -Match 'graph\.microsoft\.com/\.default'
            $switchBody | Should -Not -Match 'vault\.azure\.net/\.default'
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

    Context 'Runtime authentication paths' {
        It 'throws clearly when ServicePrincipalSecret has no resolved client secret' {
            $profile = [pscustomobject]@{
                Id       = 'azure-sp'
                Name     = 'Azure SP'
                Provider = 'Azure'
                Method   = 'ServicePrincipalSecret'
                Settings = [pscustomobject]@{
                    TenantId = '11111111-1111-1111-1111-111111111111'
                    ClientId = '22222222-2222-2222-2222-222222222222'
                }
                Secrets  = [pscustomobject]@{}
            }

            { Connect-CIEMAzure -AuthenticationProfile $profile } | Should -Throw '*ClientSecret*Profile (resolved)*MISSING*'
        }

        It 'throws the upload guidance error when ServicePrincipalCertificate has no PFX certificate' {
            $profile = [pscustomobject]@{
                Id       = 'azure-cert'
                Name     = 'Azure Certificate'
                Provider = 'Azure'
                Method   = 'ServicePrincipalCertificate'
                Settings = [pscustomobject]@{
                    TenantId = '11111111-1111-1111-1111-111111111111'
                    ClientId = '22222222-2222-2222-2222-222222222222'
                }
                Secrets  = [pscustomobject]@{}
            }

            { Connect-CIEMAzure -AuthenticationProfile $profile } | Should -Throw '*Upload a PFX file on the Configuration page*'
        }

        It 'throws clearly when ManagedIdentity environment variables are missing' {
            $originalEndpoint = $env:IDENTITY_ENDPOINT
            $originalHeader = $env:IDENTITY_HEADER
            Remove-Item Env:\IDENTITY_ENDPOINT -ErrorAction SilentlyContinue
            Remove-Item Env:\IDENTITY_HEADER -ErrorAction SilentlyContinue
            try {
                $profile = [pscustomobject]@{
                    Id       = 'azure-msi'
                    Name     = 'Azure Managed Identity'
                    Provider = 'Azure'
                    Method   = 'ManagedIdentity'
                    Settings = [pscustomobject]@{}
                    Secrets  = [pscustomobject]@{}
                }

                { Connect-CIEMAzure -AuthenticationProfile $profile } | Should -Throw '*IDENTITY_ENDPOINT and IDENTITY_HEADER must be set*'
            }
            finally {
                if ($null -ne $originalEndpoint) { $env:IDENTITY_ENDPOINT = $originalEndpoint }
                if ($null -ne $originalHeader) { $env:IDENTITY_HEADER = $originalHeader }
            }
        }

        It 'acquires ServicePrincipalSecret tokens and returns only enabled filtered subscriptions' {
            Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
                if ($Uri -match 'login\.microsoftonline\.com') {
                    return [pscustomobject]@{
                        access_token = "token:$($Body.scope)"
                        expires_in   = 3600
                    }
                }
                if ($Uri -match 'management\.azure\.com/subscriptions') {
                    return [pscustomobject]@{
                        value = @(
                            [pscustomobject]@{ subscriptionId = 'sub-enabled'; state = 'Enabled' }
                            [pscustomobject]@{ subscriptionId = 'sub-disabled'; state = 'Disabled' }
                            [pscustomobject]@{ subscriptionId = 'sub-unfiltered'; state = 'Enabled' }
                        )
                    }
                }
                throw "Unexpected URI $Uri"
            }

            $profile = [pscustomobject]@{
                Id       = 'azure-sp'
                Name     = 'Azure SP'
                Provider = 'Azure'
                Method   = 'ServicePrincipalSecret'
                Settings = [pscustomobject]@{
                    TenantId = '11111111-1111-1111-1111-111111111111'
                    ClientId = '22222222-2222-2222-2222-222222222222'
                }
                Secrets  = [pscustomobject]@{
                    ClientSecret = 'resolved-secret'
                }
            }

            $result = Connect-CIEMAzure -AuthenticationProfile $profile

            $result.TenantId | Should -Be '11111111-1111-1111-1111-111111111111'
            $result.AccountId | Should -Be '22222222-2222-2222-2222-222222222222'
            $result.AccountType | Should -Be 'ServicePrincipal'
            @($result.SubscriptionIds) | Should -Be @('sub-enabled')
            Should -Invoke -ModuleName Devolutions.CIEM Invoke-RestMethod -Times 3 -ParameterFilter {
                $Uri -match 'login\.microsoftonline\.com'
            }
            Should -Invoke -ModuleName Devolutions.CIEM Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -match 'management\.azure\.com/subscriptions'
            }
        }
    }
}
