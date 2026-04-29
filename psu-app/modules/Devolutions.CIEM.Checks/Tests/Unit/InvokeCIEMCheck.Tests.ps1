BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    InModuleScope Devolutions.CIEM {
        $script:testCheck = [CIEMCheck]::new()
        $script:testCheck.Id = 'test-check-001'
        $script:testCheck.Title = 'Test Check'
        $script:testCheck.Service = 'TestService'
        $script:testCheck.Severity = [CIEMCheckSeverity]::high
        $script:testCheck.CheckScript = 'Test-Check001'
        $script:testCheck.Description = 'A test check'
        $script:testCheck.Risk = 'Test risk'
        $script:testCheck.Provider = 'Azure'
        $script:testCheck.Disabled = $false
    }
}

Describe 'InvokeCIEMCheck' {
    Context 'when check throws and config requests continueOnError' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-CIEMConfig {
                [PSCustomObject]@{
                    scan = [PSCustomObject]@{ continueOnError = $true }
                }
            }
            InModuleScope Devolutions.CIEM {
                function script:Test-FailingCheck { throw 'Check execution error' }
            }
        }

        It 'throws the original error instead of converting it to SKIPPED' {
            InModuleScope Devolutions.CIEM {
                { InvokeCIEMCheck -Check $script:testCheck -FunctionName 'Test-FailingCheck' -ProviderName 'Azure' } |
                    Should -Throw '*Check execution error*'
            }
        }
    }

    Context 'when check throws and continueOnError is false' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-CIEMConfig {
                [PSCustomObject]@{
                    scan = [PSCustomObject]@{ continueOnError = $false }
                }
            }
            InModuleScope Devolutions.CIEM {
                function script:Test-FailingCheck2 { throw 'Critical check failure' }
            }
        }

        It 'throws the original error' {
            InModuleScope Devolutions.CIEM {
                { InvokeCIEMCheck -Check $script:testCheck -FunctionName 'Test-FailingCheck2' -ProviderName 'Azure' } |
                    Should -Throw '*Critical check failure*'
            }
        }
    }

    Context 'when check throws and Get-CIEMConfig also throws' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-CIEMConfig { throw 'Config unavailable' }
            InModuleScope Devolutions.CIEM {
                function script:Test-FailingCheck3 { throw 'Original check error' }
            }
        }

        It 'throws the original check error (not the config error)' {
            InModuleScope Devolutions.CIEM {
                { InvokeCIEMCheck -Check $script:testCheck -FunctionName 'Test-FailingCheck3' -ProviderName 'Azure' } |
                    Should -Throw '*Original check error*'
            }
        }
    }
}
