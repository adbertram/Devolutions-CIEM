BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    InModuleScope Devolutions.CIEM { $script:DatabasePath = "$TestDrive/ciem.db" }
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Get-CIEMPSUJobOutput' {
    It 'Is exported for PSU page scriptblocks' {
        Get-Command Get-CIEMPSUJobOutput -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'Returns structured PSU job output messages without ANSI escape sequences' {
        $job = [pscustomobject]@{ Id = 42 }
        Mock -ModuleName Devolutions.CIEM Get-PSUJobOutput {
            [pscustomobject]@{ Message = "$([char]27)[32;1mAttackPathId    : $([char]27)[0mattack-path-1" }
            [pscustomobject]@{ Message = 'Remediation commands completed. Rerun Azure discovery in CIEM.' }
        }

        $result = InModuleScope Devolutions.CIEM -Parameters @{ job = $job } {
            param($job)
            @(Get-CIEMPSUJobOutput -Job $job -Integrated)
        }

        $result | Should -HaveCount 2
        $result[0] | Should -Be 'AttackPathId    : attack-path-1'
        $result[1] | Should -Be 'Remediation commands completed. Rerun Azure discovery in CIEM.'
        Should -Invoke -CommandName Get-PSUJobOutput -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
            $Job.Id -eq 42 -and $AsObject -and $Integrated
        }
    }

    It 'Throws when PSU job output does not contain a message' {
        $job = [pscustomobject]@{ Id = 43 }
        Mock -ModuleName Devolutions.CIEM Get-PSUJobOutput {
            [pscustomobject]@{ Data = 'missing message' }
        }

        {
            InModuleScope Devolutions.CIEM -Parameters @{ job = $job } {
                param($job)
                Get-CIEMPSUJobOutput -Job $job -Integrated
            }
        } | Should -Throw '*output entry message is missing*'
    }
}
