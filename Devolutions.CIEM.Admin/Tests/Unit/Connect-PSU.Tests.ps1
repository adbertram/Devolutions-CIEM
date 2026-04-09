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
    Context 'when -Local is used with LOCAL_PSU_URL in .env' {
        BeforeAll {
            $script:envFile = Join-Path $TestDrive '.env'
            Set-Content -Path $script:envFile -Value @'
LOCAL_PSU_URL=http://192.168.86.30:5001
LOCAL_PSU_TOKEN=fake-local-token
'@

            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod { @() }

            $script:connectResult = Connect-PSU -Local -EnvFilePath $script:envFile -WarningAction SilentlyContinue
        }

        It 'reads the URL from LOCAL_PSU_URL in .env' {
            $script:connectResult.Url | Should -Be 'http://192.168.86.30:5001'
        }

        It 'reports a connected status' {
            $script:connectResult.Status | Should -Be 'Connected'
        }
    }

    Context 'when -Local is used without LOCAL_PSU_URL in .env' {
        BeforeAll {
            $script:envFile = Join-Path $TestDrive '.env-no-url'
            Set-Content -Path $script:envFile -Value @'
LOCAL_PSU_TOKEN=fake-local-token
'@
        }

        It 'throws requiring LOCAL_PSU_URL to be set' {
            { Connect-PSU -Local -EnvFilePath $script:envFile -WarningAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '*LOCAL_PSU_URL*'
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
}
