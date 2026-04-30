BeforeAll {
    if (-not (Get-Module -Name Universal)) {
        New-Module -Name Universal -ScriptBlock {
            function Sync-PSUConfiguration { param([switch]$Reset) }
        } | Import-Module
    }

    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest

    InModuleScope Devolutions.CIEM.Admin {
        $script:PSUConnection.Url = 'https://fake.ngrok-free.app'
        $script:PSUConnection.Token = 'fake-token'
        $script:PSUConnection.IsAzure = $false
    }
}

# Every remaining public PSU REST cmdlet in this module must include the
# 'ngrok-skip-browser-warning' header on every Invoke-RestMethod call.
# Without it, ngrok free tunnels return an HTML interstitial that silently
# breaks JSON parsing — which manifests as "App not found" / empty list bugs
# downstream (like the malformed-DB recovery flow that prompted this fix).
Describe 'PSU admin REST cmdlets send the ngrok-skip-browser-warning header' {
    BeforeEach {
        $script:capturedCalls = [System.Collections.Generic.List[object]]::new()

        Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
            $script:capturedCalls.Add([PSCustomObject]@{
                Uri     = $Uri
                Method  = $Method
                Headers = $Headers
            })

            switch -Regex ($Uri) {
                '/api/v1/dashboard$' {
                    return @([PSCustomObject]@{ id = 1; name = 'Devolutions CIEM' })
                }
                '/api/v1/dashboard/\d+/status$' { return $null }
                '/api/v1/dashboard/\d+/status/restart$' { return $null }
                '/api/v1/dashboard/\d+$' {
                    return [PSCustomObject]@{ id = 1; name = 'Devolutions CIEM' }
                }
                '/api/v1/module$' {
                    return @([PSCustomObject]@{ id = 1; name = 'Devolutions.CIEM'; version = '0.1.0' })
                }
                '/api/v1/module/\d+$' { return $null }
                '/api/v1/module/find/.*' {
                    return @([PSCustomObject]@{ name = 'Devolutions.CIEM'; version = '0.1.0' })
                }
                '/api/v1/module/save$' { return $null }
                '/api/v1/configuration' { return $null }
                default { return $null }
            }
        }
    }

    Context 'Get-PSUModule' {
        It 'sends ngrok-skip-browser-warning on every request' {
            Get-PSUModule | Out-Null
            $script:capturedCalls.Count | Should -BeGreaterThan 0
            foreach ($call in $script:capturedCalls) {
                $call.Headers['ngrok-skip-browser-warning'] |
                    Should -Not -BeNullOrEmpty -Because "GET $($call.Uri) must bypass the ngrok interstitial"
            }
        }
    }

    Context 'Install-PSUModule' {
        It 'sends ngrok-skip-browser-warning on every request' {
            Install-PSUModule -Name 'Devolutions.CIEM' -NoSync | Out-Null
            $script:capturedCalls.Count | Should -BeGreaterThan 0
            foreach ($call in $script:capturedCalls) {
                $call.Headers['ngrok-skip-browser-warning'] |
                    Should -Not -BeNullOrEmpty -Because "$($call.Method) $($call.Uri) must bypass the ngrok interstitial"
            }
        }

        It 'throws when configuration sync fails after module save' {
            Mock -ModuleName Devolutions.CIEM.Admin Sync-PSUConfiguration { throw 'mock sync failed' }

            { Install-PSUModule -Name 'Devolutions.CIEM' } |
                Should -Throw -ExpectedMessage '*mock sync failed*'
        }
    }

    Context 'Remove-PSUModule' {
        It 'sends ngrok-skip-browser-warning on every request' {
            Mock -ModuleName Devolutions.CIEM.Admin Sync-PSUConfiguration {}

            Remove-PSUModule -Name 'Devolutions.CIEM' -Force -WarningAction SilentlyContinue | Out-Null
            $script:capturedCalls.Count | Should -BeGreaterThan 0
            foreach ($call in $script:capturedCalls) {
                $call.Headers['ngrok-skip-browser-warning'] |
                    Should -Not -BeNullOrEmpty -Because "$($call.Method) $($call.Uri) must bypass the ngrok interstitial"
            }
        }

        It 'throws when module delete fails' {
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                if ($Method -eq 'Delete') {
                    throw 'mock delete failed'
                }

                @([PSCustomObject]@{ id = 1; name = 'Devolutions.CIEM'; version = '0.1.0' })
            }

            { Remove-PSUModule -Name 'Devolutions.CIEM' -Force -WarningAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '*mock delete failed*'
        }

        It 'throws when configuration sync fails after module delete' {
            Mock -ModuleName Devolutions.CIEM.Admin Sync-PSUConfiguration { throw 'mock remove sync failed' }

            { Remove-PSUModule -Name 'Devolutions.CIEM' -Force -WarningAction SilentlyContinue } |
                Should -Throw -ExpectedMessage '*mock remove sync failed*'
        }
    }
}
