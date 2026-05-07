BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    $script:InvokeCheckSource = Get-Content -Path (Join-Path $PSScriptRoot '..' '..' 'Private' 'InvokeCIEMCheck.ps1') -Raw

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

    Context 'parameter typing across PSU runspace boundaries' {
        # PSU's long-lived runspace accumulates fresh class assemblies on each
        # Import-Module of Devolutions.CIEM. Functions called from the parallel
        # scan runspace must NOT type their parameters with module-defined
        # classes ([CIEMCheck], [CIEMServiceCache]), or parameter binding fails
        # with `Cannot convert the "CIEMCheck" value of type "CIEMCheck" to type
        # "CIEMCheck"`.
        It 'Check parameter is not typed [CIEMCheck] (avoids cross-import class-identity binding errors)' {
            $script:InvokeCheckSource | Should -Not -Match '\[CIEMCheck\]\$Check\b'
        }

        It 'ServiceCache parameter is not typed [CIEMServiceCache[]]' {
            $script:InvokeCheckSource | Should -Not -Match '\[CIEMServiceCache\[\]\]\$ServiceCache\b'
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
