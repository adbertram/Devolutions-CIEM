BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Set-CIEMAWSAuthenticationProfile' {
    BeforeEach {
        Mock -ModuleName Devolutions.CIEM Set-PSUCache {}
    }

    It 'exports the AWS authentication profile command' {
        Get-Command -Module Devolutions.CIEM -Name Set-CIEMAWSAuthenticationProfile -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'persists CurrentProfile metadata to the AWS authentication cache key' {
        $result = Set-CIEMAWSAuthenticationProfile -Method CurrentProfile -Profile 'ciem-dev' -Region 'us-west-2'

        $result.Method | Should -Be 'CurrentProfile'
        $result.Profile | Should -Be 'ciem-dev'
        $result.Region | Should -Be 'us-west-2'

        Should -Invoke -CommandName Set-PSUCache -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
            $Key -eq 'CIEM:AuthProfile:AWS' -and
            $Value.Method -eq 'CurrentProfile' -and
            $Value.Profile -eq 'ciem-dev' -and
            $Value.Region -eq 'us-west-2' -and
            $Persist -and
            $Integrated
        }
    }

    It 'persists AccessKey metadata without storing secrets in the cache value' {
        $result = Set-CIEMAWSAuthenticationProfile -Method AccessKey -Region 'ca-central-1'

        $result.Method | Should -Be 'AccessKey'
        $result.Region | Should -Be 'ca-central-1'
        $result.PSObject.Properties.Name | Should -Not -Contain 'AccessKeyId'
        $result.PSObject.Properties.Name | Should -Not -Contain 'SecretAccessKey'

        Should -Invoke -CommandName Set-PSUCache -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
            $Key -eq 'CIEM:AuthProfile:AWS' -and
            $Value.Method -eq 'AccessKey' -and
            $Value.Region -eq 'ca-central-1' -and
            $Value.PSObject.Properties.Name -notcontains 'AccessKeyId' -and
            $Value.PSObject.Properties.Name -notcontains 'SecretAccessKey'
        }
    }
}
