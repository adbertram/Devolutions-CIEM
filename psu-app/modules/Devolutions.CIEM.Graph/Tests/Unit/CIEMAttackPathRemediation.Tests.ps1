BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Invoke-CIEMAttackPathRemediation' {

    Context 'Command structure' {
        It 'Is available as a public command' {
            Get-Command Invoke-CIEMAttackPathRemediation -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory AttackPathId parameter for PSU script invocation' {
            $param = (Get-Command Invoke-CIEMAttackPathRemediation).Parameters['AttackPathId']
            $param | Should -Not -BeNullOrEmpty

            $parameterAttribute = @($param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })[0]
            $parameterAttribute.Mandatory | Should -BeTrue
            $parameterAttribute.ValueFromPipeline | Should -BeFalse
        }

        It 'Supports ShouldProcess for -WhatIf and -Confirm' {
            $command = Get-Command Invoke-CIEMAttackPathRemediation
            $command.Parameters.ContainsKey('WhatIf') | Should -BeTrue
            $command.Parameters.ContainsKey('Confirm') | Should -BeTrue
        }
    }

    Context 'Execution behavior' {

        It 'Executes remediation script and returns completion metadata' {
            $filePath = Join-Path $TestDrive 'attack-path-remediation-executed.txt'
            $escapedPath = $filePath.Replace("'", "''")

            Mock -ModuleName Devolutions.CIEM Get-CIEMAttackPath {
                [pscustomobject]@{
                    Id                    = 'attack-path-1'
                    PatternId             = 'open-management-port'
                    PatternName           = 'Management port open to the internet'
                    RemediationScriptPath = 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/management-port-open-to-the-internet.ps1'
                }
            }
            Mock -ModuleName Devolutions.CIEM Get-CIEMAttackPathRemediationScript {
                "Set-Content -Path '$escapedPath' -Value 'executed'"
            } -ParameterFilter {
                $Id -eq 'attack-path-1'
            }

            $result = Invoke-CIEMAttackPathRemediation -AttackPathId 'attack-path-1' -Confirm:$false

            $filePath | Should -Exist
            ((Get-Content $filePath -Raw).Trim()) | Should -Be 'executed'
            $result.AttackPathId | Should -Be 'attack-path-1'
            $result.PatternId | Should -Be 'open-management-port'
            $result.PatternName | Should -Be 'Management port open to the internet'
            $result.RemediationScriptPath | Should -Be 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/management-port-open-to-the-internet.ps1'
            $result.Status | Should -Be 'Completed'
            $result.DurationSeconds | Should -BeGreaterOrEqual 0
            Should -Invoke -CommandName Get-CIEMAttackPathRemediationScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
                $Id -eq 'attack-path-1'
            }
        }

        It 'Does not execute remediation script when -WhatIf is specified' {
            $filePath = Join-Path $TestDrive 'attack-path-remediation-whatif.txt'
            $escapedPath = $filePath.Replace("'", "''")

            Mock -ModuleName Devolutions.CIEM Get-CIEMAttackPath {
                [pscustomobject]@{
                    Id          = 'whatif-test'
                    PatternId   = 'whatif-test'
                    PatternName = 'WhatIf Test'
                }
            }
            Mock -ModuleName Devolutions.CIEM Get-CIEMAttackPathRemediationScript {
                "Set-Content -Path '$escapedPath' -Value 'should-not-run'"
            }

            $result = @(Invoke-CIEMAttackPathRemediation -AttackPathId 'whatif-test' -WhatIf)

            $filePath | Should -Not -Exist
            $result | Should -HaveCount 0
        }

        It 'Throws when the attack path id is not found' {
            Mock -ModuleName Devolutions.CIEM Get-CIEMAttackPath { @() }

            { Invoke-CIEMAttackPathRemediation -AttackPathId 'missing-path' -Confirm:$false } | Should -Throw "*attack path 'missing-path' was not found*"
        }

        It 'Throws when the rendered remediation script is empty' {
            Mock -ModuleName Devolutions.CIEM Get-CIEMAttackPath {
                [pscustomobject]@{
                    Id          = 'empty-script'
                    PatternId   = 'empty-script'
                    PatternName = 'Empty Script'
                }
            }
            Mock -ModuleName Devolutions.CIEM Get-CIEMAttackPathRemediationScript { '' }

            { Invoke-CIEMAttackPathRemediation -AttackPathId 'empty-script' -Confirm:$false } | Should -Throw '*rendered remediation script is empty*'
        }
    }
}
