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

        It 'Has mandatory AttackPath parameter that accepts pipeline input' {
            $param = (Get-Command Invoke-CIEMAttackPathRemediation).Parameters['AttackPath']
            $param | Should -Not -BeNullOrEmpty

            $parameterAttribute = @($param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })[0]
            $parameterAttribute.Mandatory | Should -BeTrue
            $parameterAttribute.ValueFromPipeline | Should -BeTrue
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

            $attackPath = InModuleScope Devolutions.CIEM -Parameters @{ filePath = $filePath } {
                param($filePath)
                $item = [CIEMAttackPath]::new()
                $item.PatternId = 'open-management-port'
                $item.PatternName = 'Management port open to the internet'
                $item.RemediationScriptPath = 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/management-port-open-to-the-internet.ps1'
                $escapedPath = $filePath.Replace("'", "''")
                $item.RemediationScript = "Set-Content -Path '$escapedPath' -Value 'executed'"
                $item
            }

            $result = $attackPath | Invoke-CIEMAttackPathRemediation -Confirm:$false

            $filePath | Should -Exist
            ((Get-Content $filePath -Raw).Trim()) | Should -Be 'executed'
            $result.PatternId | Should -Be 'open-management-port'
            $result.PatternName | Should -Be 'Management port open to the internet'
            $result.RemediationScriptPath | Should -Be 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/management-port-open-to-the-internet.ps1'
            $result.Status | Should -Be 'Completed'
            $result.DurationSeconds | Should -BeGreaterOrEqual 0
        }

        It 'Does not execute remediation script when -WhatIf is specified' {
            $filePath = Join-Path $TestDrive 'attack-path-remediation-whatif.txt'

            $attackPath = InModuleScope Devolutions.CIEM -Parameters @{ filePath = $filePath } {
                param($filePath)
                $item = [CIEMAttackPath]::new()
                $item.PatternId = 'whatif-test'
                $escapedPath = $filePath.Replace("'", "''")
                $item.RemediationScript = "Set-Content -Path '$escapedPath' -Value 'should-not-run'"
                $item
            }

            $result = @($attackPath | Invoke-CIEMAttackPathRemediation -WhatIf)

            $filePath | Should -Not -Exist
            $result | Should -HaveCount 0
        }

        It 'Throws when attack path has no remediation script' {
            $attackPath = InModuleScope Devolutions.CIEM {
                $item = [CIEMAttackPath]::new()
                $item.PatternId = 'missing-script'
                $item
            }

            { $attackPath | Invoke-CIEMAttackPathRemediation -Confirm:$false } | Should -Throw '*RemediationScript is empty*'
        }
    }
}
