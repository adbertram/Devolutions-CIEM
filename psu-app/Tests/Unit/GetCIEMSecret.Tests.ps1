BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Get-CIEMSecret' {

    Context 'when not in PSU context (Secret: drive absent)' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-PSDrive { $null } -ParameterFilter { $Name -eq 'Secret' }
        }

        It 'throws indicating PSU context is required' {
            { Get-CIEMSecret -Name 'TestSecret' } | Should -Throw '*Not running in PSU context*'
        }
    }

    Context 'when in PSU context and secret exists' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-PSDrive { [PSCustomObject]@{ Name = 'Secret' } } -ParameterFilter { $Name -eq 'Secret' }
            Mock -ModuleName Devolutions.CIEM Get-Item { 'my-secret-value' } -ParameterFilter { $Path -eq 'Secret:TestSecret' }
            $script:result = Get-CIEMSecret -Name 'TestSecret'
        }

        It 'returns the secret value' {
            $script:result | Should -Be 'my-secret-value'
        }
    }

    Context 'when in PSU context and secret does not exist' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-PSDrive { [PSCustomObject]@{ Name = 'Secret' } } -ParameterFilter { $Name -eq 'Secret' }
            Mock -ModuleName Devolutions.CIEM Get-Item { throw "Cannot find path 'Secret:MissingSecret'" } -ParameterFilter { $Path -eq 'Secret:MissingSecret' }
        }

        It 'throws when secret is not found' {
            { Get-CIEMSecret -Name 'MissingSecret' } | Should -Throw
        }
    }
}
