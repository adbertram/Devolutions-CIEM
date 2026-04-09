BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'InvokeCIEMDiscoveryPhase' {

    Context 'Command structure' {
        It 'Exists as a private function within the module' {
            InModuleScope Devolutions.CIEM {
                Get-Command -Name 'InvokeCIEMDiscoveryPhase' -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has mandatory Name parameter' {
            InModuleScope Devolutions.CIEM {
                $cmd = Get-Command InvokeCIEMDiscoveryPhase
                $cmd.Parameters['Name'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                    ForEach-Object { $_.Mandatory | Should -BeTrue }
            }
        }

        It 'Has mandatory Action parameter' {
            InModuleScope Devolutions.CIEM {
                $cmd = Get-Command InvokeCIEMDiscoveryPhase
                $cmd.Parameters['Action'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                    ForEach-Object { $_.Mandatory | Should -BeTrue }
            }
        }

        It 'Has mandatory ErrorMessages parameter' {
            InModuleScope Devolutions.CIEM {
                $cmd = Get-Command InvokeCIEMDiscoveryPhase
                $cmd.Parameters['ErrorMessages'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                    ForEach-Object { $_.Mandatory | Should -BeTrue }
            }
        }

        It 'Has mandatory WarningCounter parameter' {
            InModuleScope Devolutions.CIEM {
                $cmd = Get-Command InvokeCIEMDiscoveryPhase
                $cmd.Parameters['WarningCounter'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                    ForEach-Object { $_.Mandatory | Should -BeTrue }
            }
        }
    }

    Context 'Accepts empty ErrorMessages list' {
        It 'Does not throw when ErrorMessages is an empty List[string]' {
            InModuleScope Devolutions.CIEM {
                $errorMessages = [System.Collections.Generic.List[string]]::new()
                $warningCounter = [ref]0

                $result = InvokeCIEMDiscoveryPhase `
                    -Name 'TestPhase' `
                    -ErrorMessages $errorMessages `
                    -WarningCounter $warningCounter `
                    -Action { 'hello' }

                $result.Succeeded | Should -BeTrue
                $result.Result | Should -Be 'hello'
            }
        }
    }

    Context 'Successful phase execution' {
        BeforeAll {
            InModuleScope Devolutions.CIEM {
                $script:testErrors = [System.Collections.Generic.List[string]]::new()
                $script:testWarnings = [ref]0

                $script:testResult = InvokeCIEMDiscoveryPhase `
                    -Name 'SuccessPhase' `
                    -ErrorMessages $script:testErrors `
                    -WarningCounter $script:testWarnings `
                    -Action { 42 }
            }
        }

        It 'Returns Succeeded = true' {
            InModuleScope Devolutions.CIEM {
                $script:testResult.Succeeded | Should -BeTrue
            }
        }

        It 'Returns the action output as Result' {
            InModuleScope Devolutions.CIEM {
                $script:testResult.Result | Should -Be 42
            }
        }

        It 'Does not add to ErrorMessages' {
            InModuleScope Devolutions.CIEM {
                $script:testErrors | Should -HaveCount 0
            }
        }

        It 'Does not increment WarningCounter' {
            InModuleScope Devolutions.CIEM {
                $script:testWarnings.Value | Should -Be 0
            }
        }

        It 'Includes ElapsedSeconds in the output' {
            InModuleScope Devolutions.CIEM {
                $script:testResult.ElapsedSeconds | Should -BeGreaterOrEqual 0
            }
        }
    }

    Context 'Failed phase execution' {
        BeforeAll {
            InModuleScope Devolutions.CIEM {
                $script:failErrors = [System.Collections.Generic.List[string]]::new()
                $script:failWarnings = [ref]0

                $script:failResult = InvokeCIEMDiscoveryPhase `
                    -Name 'FailPhase' `
                    -ErrorMessages $script:failErrors `
                    -WarningCounter $script:failWarnings `
                    -Action { throw 'Something went wrong' }
            }
        }

        It 'Returns Succeeded = false' {
            InModuleScope Devolutions.CIEM {
                $script:failResult.Succeeded | Should -BeFalse
            }
        }

        It 'Returns null Result' {
            InModuleScope Devolutions.CIEM {
                $script:failResult.Result | Should -BeNullOrEmpty
            }
        }

        It 'Appends phase-prefixed message to ErrorMessages' {
            InModuleScope Devolutions.CIEM {
                $script:failErrors | Should -HaveCount 1
                $script:failErrors[0] | Should -Match 'FailPhase failed: Something went wrong'
            }
        }

        It 'Increments WarningCounter' {
            InModuleScope Devolutions.CIEM {
                $script:failWarnings.Value | Should -Be 1
            }
        }
    }

    Context 'DetailBuilder callback' {
        It 'Calls DetailBuilder with action result on success' {
            InModuleScope Devolutions.CIEM {
                $errors = [System.Collections.Generic.List[string]]::new()
                $warnings = [ref]0
                $detailCapture = $null

                $result = InvokeCIEMDiscoveryPhase `
                    -Name 'DetailPhase' `
                    -ErrorMessages $errors `
                    -WarningCounter $warnings `
                    -DetailBuilder { param($r) "got $r items" } `
                    -Action { 99 }

                $result.Succeeded | Should -BeTrue
            }
        }
    }
}
