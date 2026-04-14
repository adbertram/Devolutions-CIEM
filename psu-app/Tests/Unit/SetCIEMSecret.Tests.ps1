BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Set-CIEMSecret' {

    Context 'when not in PSU context (Secret: drive absent)' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-PSDrive { $null } -ParameterFilter { $Name -eq 'Secret' }
        }

        It 'throws indicating PSU context is required' {
            { Set-CIEMSecret -Name 'TestSecret' -Value 'test-value' } | Should -Throw '*Not running in PSU context*'
        }
    }

    Context 'when in PSU context and variable already exists' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-PSDrive { [PSCustomObject]@{ Name = 'Secret' } } -ParameterFilter { $Name -eq 'Secret' }
            Mock -ModuleName Devolutions.CIEM Get-PSUVariable { [PSCustomObject]@{ Name = 'TestSecret'; Value = 'old-value' } }
            Mock -ModuleName Devolutions.CIEM Set-PSUVariable {}
        }

        It 'updates the existing variable' {
            Set-CIEMSecret -Name 'TestSecret' -Value 'new-value'
            Should -Invoke -CommandName Set-PSUVariable -ModuleName Devolutions.CIEM -Times 1 -Exactly
        }
    }

    Context 'when in PSU context and variable does not exist' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-PSDrive { [PSCustomObject]@{ Name = 'Secret' } } -ParameterFilter { $Name -eq 'Secret' }
            Mock -ModuleName Devolutions.CIEM Get-PSUVariable { $null }
            Mock -ModuleName Devolutions.CIEM New-PSUVariable {}
        }

        It 'creates a new variable in the vault' {
            Set-CIEMSecret -Name 'NewSecret' -Value 'secret-value'
            Should -Invoke -CommandName New-PSUVariable -ModuleName Devolutions.CIEM -Times 1 -Exactly
        }
    }
}
