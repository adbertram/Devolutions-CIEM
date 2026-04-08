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
    Context 'when -Local is used and ngrok CLI writes a status line to stderr' {
        BeforeAll {
            # Real ngrok CLI writes the JSON response to stdout AND a '200 OK'
            # HTTP status line to stderr. The buggy code captured both with
            # `2>&1 | Out-String` and handed the merged text to ConvertFrom-Json,
            # which failed with a "Additional text encountered after finished
            # reading JSON content" error.
            Mock -ModuleName Devolutions.CIEM.Admin ngrok {
                # Real ngrok writes the HTTP status line to stderr AND the JSON
                # body to stdout. Buggy code merged them with 2>&1, corrupting
                # the JSON. Inside a PowerShell function, Write-Error flows
                # through the PS error stream so `2>&1` redirection actually
                # captures it (matching how native process stderr is captured).
                Write-Output @'
{
  "next_page_uri": null,
  "tunnels": [
    {
      "forwards_to": "http://localhost:5001",
      "public_url": "https://mocked.ngrok-free.app",
      "proto": "https"
    }
  ],
  "uri": "https://api.ngrok.com/tunnels"
}
'@
                Write-Error '200 OK' -ErrorAction Continue
                $global:LASTEXITCODE = 0
            }

            # Network call to PSU must not reach the wire
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod { @() }

            $script:connectResult = Connect-PSU -Local -Token 'fake-token' -EnvFilePath 'NO_ENV_FILE' -WarningAction SilentlyContinue
        }

        It 'parses ngrok JSON cleanly even when stderr contains a status line' {
            $script:connectResult | Should -Not -BeNullOrEmpty
        }

        It 'resolves the tunnel URL from ngrok stdout JSON' {
            $script:connectResult.Url | Should -Be 'https://mocked.ngrok-free.app'
        }

        It 'reports a connected status' {
            $script:connectResult.Status | Should -Be 'Connected'
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
