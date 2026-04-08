BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest

    # Pre-populate the module's PSU connection state so Invoke-CIEMCommand
    # does not attempt to auto-connect.
    InModuleScope Devolutions.CIEM.Admin {
        $script:PSUConnection.Url = 'https://fake.ngrok-free.app'
        $script:PSUConnection.Token = 'fake-token'
        $script:PSUConnection.IsAzure = $false
    }
}

Describe 'Invoke-CIEMCommand' {
    Context 'when the PSU executor script already exists' {
        BeforeAll {
            # Track every Invoke-RestMethod call so the test can assert
            # (a) no duplicate POST was attempted and
            # (b) every request carried the ngrok skip header.
            $script:calls = [System.Collections.Generic.List[object]]::new()

            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                $script:calls.Add([PSCustomObject]@{
                    Uri     = $Uri
                    Method  = $Method
                    Headers = $Headers
                    Body    = $Body
                })

                switch -Regex ($Uri) {
                    '/api/v1/script$' {
                        # Return the list of existing scripts — CIEMExecutor.ps1 already exists
                        return @(
                            [PSCustomObject]@{ id = 1; name = 'CIEMExecutor.ps1'; fullPath = 'CIEMExecutor.ps1' }
                            [PSCustomObject]@{ id = 2; name = 'Other.ps1'; fullPath = 'Other.ps1' }
                        )
                    }
                    '/api/v1/script/\d+\?' {
                        # Script invocation → return a job id
                        return 42
                    }
                    '/api/v1/job/42/output' {
                        return @('mock output')
                    }
                    '/api/v1/job/42/pipelineOutput' {
                        return @('mock pipeline')
                    }
                    '/api/v1/job/42' {
                        return [PSCustomObject]@{
                            id        = 42
                            status    = 2  # Completed
                            startTime = (Get-Date)
                            endTime   = (Get-Date)
                        }
                    }
                }
            }

            $script:result = Invoke-CIEMCommand -Command 'Get-Date' -TimeoutSeconds 5 -Verbose
        }

        It 'reuses the existing executor script instead of POSTing a duplicate' {
            $postCalls = $script:calls | Where-Object { $_.Method -eq 'Post' -and $_.Uri -match '/api/v1/script$' }
            $postCalls | Should -BeNullOrEmpty
        }

        It 'invokes the existing executor by id' {
            $invocation = $script:calls | Where-Object { $_.Uri -match '/api/v1/script/1\?' }
            $invocation | Should -Not -BeNullOrEmpty
        }

        It 'returns the job output from the mocked PSU response' {
            $script:result.Status | Should -Be 'Completed'
        }
    }

    Context 'when talking to an ngrok-fronted PSU over HTTPS' {
        BeforeAll {
            $script:ngrokCalls = [System.Collections.Generic.List[object]]::new()

            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                $script:ngrokCalls.Add([PSCustomObject]@{
                    Uri     = $Uri
                    Method  = $Method
                    Headers = $Headers
                })

                switch -Regex ($Uri) {
                    '/api/v1/script$' {
                        return @(
                            [PSCustomObject]@{ id = 1; name = 'CIEMExecutor.ps1'; fullPath = 'CIEMExecutor.ps1' }
                        )
                    }
                    '/api/v1/script/\d+\?' { return 99 }
                    '/api/v1/job/99/output' { return @() }
                    '/api/v1/job/99/pipelineOutput' { return @() }
                    '/api/v1/job/99' {
                        return [PSCustomObject]@{ id = 99; status = 2; startTime = (Get-Date); endTime = (Get-Date) }
                    }
                }
            }

            $null = Invoke-CIEMCommand -Command 'Get-Date' -TimeoutSeconds 5 -Verbose
        }

        It 'sends the ngrok-skip-browser-warning header on every PSU request' {
            $script:ngrokCalls.Count | Should -BeGreaterThan 0
            foreach ($call in $script:ngrokCalls) {
                $call.Headers['ngrok-skip-browser-warning'] |
                    Should -Not -BeNullOrEmpty -Because "request to $($call.Uri) must bypass the ngrok free-tier interstitial"
            }
        }

        It 'sends a Bearer Authorization header on every PSU request' {
            foreach ($call in $script:ngrokCalls) {
                $call.Headers['Authorization'] | Should -Match '^Bearer '
            }
        }
    }
}
