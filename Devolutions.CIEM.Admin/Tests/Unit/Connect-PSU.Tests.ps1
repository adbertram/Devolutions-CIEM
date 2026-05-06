BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest

    # Neutralize Connect-PSUServer (external Universal module cmdlet) so the
    # tests do not attempt to open a real connection.
    Mock -ModuleName Devolutions.CIEM.Admin Connect-PSUServer {}
}

Describe 'Connect-PSU' {
    Context 'when no target switch is used with LOCAL_PSU_URL in .env' {
        BeforeAll {
            $script:envFile = Join-Path $TestDrive '.env'
            Set-Content -Path $script:envFile -Value @'
LOCAL_PSU_URL=http://192.168.86.30:5001
LOCAL_PSU_TOKEN=fake-local-token
'@

            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod { @() }

            $script:connectResult = Connect-PSU -EnvFilePath $script:envFile -WarningAction SilentlyContinue
        }

        It 'reads the URL from LOCAL_PSU_URL in .env' {
            $script:connectResult.Url | Should -Be 'http://192.168.86.30:5001'
        }

        It 'marks the default target as non-Azure' {
            $script:connectResult.IsAzure | Should -BeFalse
        }

        It 'reports a connected status' {
            $script:connectResult.Status | Should -Be 'Connected'
        }
    }

    Context 'when -Azure is used with AZURE_PSU_URL in .env' {
        BeforeAll {
            $script:envFile = Join-Path $TestDrive '.env-azure'
            Set-Content -Path $script:envFile -Value @'
AZURE_PSU_URL=https://devolutions-ciem-psu.azurewebsites.net
AZURE_PSU_TOKEN=fake-azure-token
'@

            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod { @() }

            $script:connectResult = Connect-PSU -Azure -EnvFilePath $script:envFile -WarningAction SilentlyContinue
        }

        It 'reads the URL from AZURE_PSU_URL in .env' {
            $script:connectResult.Url | Should -Be 'https://devolutions-ciem-psu.azurewebsites.net'
        }

        It 'marks the target as Azure' {
            $script:connectResult.IsAzure | Should -BeTrue
        }
    }

    Context 'when no target switch is used without LOCAL_PSU_URL in .env' {
        BeforeAll {
            $script:envFile = Join-Path $TestDrive '.env-no-url'
            Set-Content -Path $script:envFile -Value @'
LOCAL_PSU_TOKEN=fake-local-token
'@
        }

        It 'throws requiring LOCAL_PSU_URL to be set' {
            { Connect-PSU -EnvFilePath $script:envFile -WarningAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '*LOCAL_PSU_URL*'
        }
    }

    Context 'when both target switches are used' {
        It 'throws because a connection must have one target' {
            { Connect-PSU -Local -Azure -EnvFilePath 'NO_ENV_FILE' -WarningAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '*either -Local or -Azure, not both*'
        }
    }

    Context 'when making the PSU probe request' {
        BeforeAll {
            $script:capturedHeaders = $null
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                $script:capturedHeaders = $Headers
                @()
            }

            $null = Connect-PSU -Url 'https://fake.ngrok-free.app' -Token 'fake-token' -EnvFilePath 'NO_ENV_FILE' -WarningAction SilentlyContinue
        }

        It 'includes an Authorization bearer header' {
            $script:capturedHeaders['Authorization'] | Should -Be 'Bearer fake-token'
        }

        It 'sends the ngrok-skip-browser-warning header so ngrok free tunnels do not return the interstitial HTML' {
            $script:capturedHeaders['ngrok-skip-browser-warning'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when the official PSU connection cmdlet is unavailable' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod { @() }
            Mock -ModuleName Devolutions.CIEM.Admin Get-Command { $null } -ParameterFilter { $Name -eq 'Connect-PSUServer' }
        }

        It 'throws instead of reporting a connected status' {
            { Connect-PSU -Url 'https://fake.psu' -Token 'fake-token' -EnvFilePath 'NO_ENV_FILE' -WarningAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '*Connect-PSUServer*'
        }
    }

    Context 'when the default local target returns HTTP 401' {
        BeforeAll {
            $script:envFile = Join-Path $TestDrive '.env-local-401'
            Set-Content -Path $script:envFile -Value @'
LOCAL_PSU_URL=http://192.168.86.30:5001
LOCAL_PSU_TOKEN=fake-local-token
'@

            $response = [pscustomobject]@{
                StatusCode = [System.Net.HttpStatusCode]::Unauthorized
            }
            $exception = [System.Management.Automation.RuntimeException]::new('401 Unauthorized')
            Add-Member -InputObject $exception -MemberType NoteProperty -Name Response -Value $response

            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                throw $exception
            }
        }

        It 'throws the local authentication guidance even without -Local' {
            { Connect-PSU -EnvFilePath $script:envFile -WarningAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '*Local PSU may not be running in development mode*'
        }
    }
}
