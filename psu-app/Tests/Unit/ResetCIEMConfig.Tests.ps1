BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Reset-CIEMConfig' {

    Context 'when PSU cache is available and write succeeds' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-Command { [PSCustomObject]@{ Name = 'Set-PSUCache' } } -ParameterFilter { $Name -eq 'Set-PSUCache' }
            Mock -ModuleName Devolutions.CIEM Set-PSUCache {}
        }

        It 'writes defaults to PSU cache' {
            Reset-CIEMConfig -Confirm:$false
            Should -Invoke -CommandName Set-PSUCache -ModuleName Devolutions.CIEM -Times 1 -Exactly
        }
    }

    Context 'when PSU cache write fails' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-Command { [PSCustomObject]@{ Name = 'Set-PSUCache' } } -ParameterFilter { $Name -eq 'Set-PSUCache' }
            Mock -ModuleName Devolutions.CIEM Set-PSUCache { throw 'PSU cache write failed' }
        }

        It 'throws the write error' {
            { Reset-CIEMConfig -Confirm:$false } | Should -Throw '*PSU cache write failed*'
        }
    }

    Context 'when not in PSU context (Set-PSUCache command absent)' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-Command { $null } -ParameterFilter { $Name -eq 'Set-PSUCache' }
        }

        It 'throws requiring PSU cache access' {
            { Reset-CIEMConfig -Confirm:$false } | Should -Throw -ExpectedMessage '*Set-PSUCache*'
        }
    }
}
