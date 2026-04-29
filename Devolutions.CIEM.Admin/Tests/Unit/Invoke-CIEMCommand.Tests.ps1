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
    Context 'when no PSU connection exists' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = $null
                $script:PSUConnection.Token = $null
                $script:PSUConnection.IsAzure = $false
            }

            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { throw 'Connect-PSU should not be called by Invoke-CIEMCommand' }
        }

        It 'throws requiring an explicit Connect-PSU call' {
            { Invoke-CIEMCommand -Command 'Get-Date' } |
                Should -Throw -ExpectedMessage '*Run Connect-PSU first*'
        }

        It 'does not auto-connect to PSU' {
            Should -Invoke -CommandName Connect-PSU -ModuleName Devolutions.CIEM.Admin -Times 0 -Exactly
        }
    }

    Context 'when the remote job exceeds the timeout' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://fake.ngrok-free.app'
                $script:PSUConnection.Token = 'fake-token'
                $script:PSUConnection.IsAzure = $false
            }

            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                switch -Regex ($Uri) {
                    '/api/v1/script$' {
                        return @(
                            [PSCustomObject]@{ id = 1; name = 'CIEMExecutor.ps1'; fullPath = 'CIEMExecutor.ps1' }
                        )
                    }
                    '/api/v1/script/\d+\?' { return 42 }
                    '/api/v1/job/42/output' { return @('late output') }
                    '/api/v1/job/42/pipelineOutput' { return @() }
                    '/api/v1/job/42' {
                        return [PSCustomObject]@{
                            id        = 42
                            status    = 1
                            startTime = (Get-Date)
                            endTime   = $null
                        }
                    }
                }
            }
        }

        It 'throws instead of returning a running result' {
            { Invoke-CIEMCommand -Command 'Start-Sleep 10' -TimeoutSeconds 0 } |
                Should -Throw -ExpectedMessage '*timed out*'
        }
    }

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

    Context 'when PSU returns WarningOutput terminal status' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://fake.ngrok-free.app'
                $script:PSUConnection.Token = 'fake-token'
                $script:PSUConnection.IsAzure = $false
            }

            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                switch -Regex ($Uri) {
                    '/api/v1/script$' {
                        return @(
                            [PSCustomObject]@{ id = 1; name = 'CIEMExecutor.ps1'; fullPath = 'CIEMExecutor.ps1' }
                        )
                    }
                    '/api/v1/script/\d+\?' { return 43 }
                    '/api/v1/job/43/output' { return @('warning output') }
                    '/api/v1/job/43/pipelineOutput' { return @('mock pipeline') }
                    '/api/v1/job/43' {
                        return [PSCustomObject]@{
                            id        = 43
                            status    = 11
                            startTime = (Get-Date)
                            endTime   = (Get-Date)
                        }
                    }
                }
            }
        }

        It 'returns WarningOutput instead of polling until timeout' {
            $result = Invoke-CIEMCommand -Command 'Write-Warning "done"' -TimeoutSeconds 0
            $result.Status | Should -Be 'WarningOutput'
        }
    }

    Context 'when the PSU job endpoint returns 401' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://fake.ngrok-free.app'
                $script:PSUConnection.Token = 'valid-token'
                $script:PSUConnection.IsAzure = $true
            }

            $script:jobPollCount = 0

            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                switch -Regex ($Uri) {
                    '/api/v1/script$' {
                        return @(
                            [PSCustomObject]@{ id = 1; name = 'CIEMExecutor.ps1'; fullPath = 'CIEMExecutor.ps1' }
                        )
                    }
                    '/api/v1/script/\d+\?' { return 44 }
                    '/api/v1/job/44/output' { return @('after reconnect') }
                    '/api/v1/job/44/pipelineOutput' { return @() }
                    '/api/v1/job/44$' {
                        $script:jobPollCount++
                        if ($script:jobPollCount -eq 1) {
                            throw 'Response status code does not indicate success: 401 (Unauthorized).'
                        }

                        if ($Headers['Authorization'] -ne 'Bearer valid-token') {
                            throw "Expected the original bearer token, got '$($Headers['Authorization'])'."
                        }

                        return [PSCustomObject]@{
                            id        = 44
                            status    = 2
                            startTime = (Get-Date)
                            endTime   = (Get-Date)
                        }
                    }
                }
            }
        }

        It 'throws immediately without retrying the same request' {
            { Invoke-CIEMCommand -Command 'Get-Date' -TimeoutSeconds 5 } |
                Should -Throw -ExpectedMessage '*401*'

            $script:jobPollCount | Should -Be 1
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
