BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Connect-CIEMAWS' {
    BeforeEach {
        $script:AwsCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Devolutions.CIEM Get-CIEMProvider {
            [pscustomobject]@{ Id = 'provider-aws'; Name = 'AWS' }
        }
        Mock -ModuleName Devolutions.CIEM aws {
            $script:AwsCalls.Add(@($args))
            $global:LASTEXITCODE = 0
            '{"Account":"123456789012","Arn":"arn:aws:iam::123456789012:user/ciem","UserId":"AIDAEXAMPLE"}'
        }
    }

    It 'passes profile and region to AWS CLI for CurrentProfile authentication and classifies the ARN' {
        $profile = [pscustomobject]@{
            Id       = 'aws-current'
            Name     = 'AWS Current Profile'
            Provider = 'AWS'
            Method   = 'CurrentProfile'
            Settings = [pscustomobject]@{
                Profile = 'ciem-prod'
                Region  = 'us-east-1'
            }
            Secrets  = [pscustomobject]@{}
        }

        $result = Connect-CIEMAWS -AuthenticationProfile $profile

        $result.AccountId | Should -Be '123456789012'
        $result.Arn | Should -Be 'arn:aws:iam::123456789012:user/ciem'
        $result.AccountType | Should -Be 'IAMUser'
        $result.Region | Should -Be 'us-east-1'
        $result.Profile | Should -Be 'ciem-prod'
        $script:AwsCalls | Should -HaveCount 1
        $script:AwsCalls[0] | Should -Be @('sts', 'get-caller-identity', '--output', 'json', '--profile', 'ciem-prod', '--region', 'us-east-1')
    }

    It 'throws when AccessKey credentials are missing' {
        $profile = [pscustomobject]@{
            Id       = 'aws-access'
            Name     = 'AWS Access Key'
            Provider = 'AWS'
            Method   = 'AccessKey'
            Settings = [pscustomobject]@{ Region = 'us-east-1' }
            Secrets  = [pscustomobject]@{ AccessKeyId = 'AKIAEXAMPLE' }
        }

        { Connect-CIEMAWS -AuthenticationProfile $profile } | Should -Throw '*SecretAccessKey*Profile (resolved)*MISSING*'
    }

    It 'clears AccessKey environment variables after successful authentication' {
        $profile = [pscustomobject]@{
            Id       = 'aws-access'
            Name     = 'AWS Access Key'
            Provider = 'AWS'
            Method   = 'AccessKey'
            Settings = [pscustomobject]@{ Region = 'us-east-1' }
            Secrets  = [pscustomobject]@{
                AccessKeyId     = 'AKIAEXAMPLE'
                SecretAccessKey = 'secret'
            }
        }

        $result = Connect-CIEMAWS -AuthenticationProfile $profile

        $result.AccountId | Should -Be '123456789012'
        Test-Path Env:\AWS_ACCESS_KEY_ID | Should -BeFalse
        Test-Path Env:\AWS_SECRET_ACCESS_KEY | Should -BeFalse
        Test-Path Env:\AWS_DEFAULT_REGION | Should -BeFalse
    }

    It 'clears AccessKey environment variables after failed authentication' {
        Mock -ModuleName Devolutions.CIEM aws {
            $script:AwsCalls.Add(@($args))
            $global:LASTEXITCODE = 42
            'access denied'
        }
        $profile = [pscustomobject]@{
            Id       = 'aws-access'
            Name     = 'AWS Access Key'
            Provider = 'AWS'
            Method   = 'AccessKey'
            Settings = [pscustomobject]@{ Region = 'us-east-1' }
            Secrets  = [pscustomobject]@{
                AccessKeyId     = 'AKIAEXAMPLE'
                SecretAccessKey = 'secret'
            }
        }

        { Connect-CIEMAWS -AuthenticationProfile $profile } | Should -Throw '*AWS AccessKey authentication failed: access denied*'

        Test-Path Env:\AWS_ACCESS_KEY_ID | Should -BeFalse
        Test-Path Env:\AWS_SECRET_ACCESS_KEY | Should -BeFalse
        Test-Path Env:\AWS_DEFAULT_REGION | Should -BeFalse
    }
}
