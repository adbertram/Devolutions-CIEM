BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    function Initialize-InfrastructureTestDatabase {
        New-CIEMDatabase -Path "$TestDrive/ciem.db"

        InModuleScope Devolutions.CIEM {
            $script:DatabasePath = "$TestDrive/ciem.db"
        }

        $schemaPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'azure_schema.sql'
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    }
}

Describe 'Invoke-AzureApi Graph batch support' {
    BeforeEach {
        Remove-Item "$TestDrive/ciem.db" -Force -ErrorAction SilentlyContinue
        Initialize-InfrastructureTestDatabase
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
        Mock -ModuleName Devolutions.CIEM InvokeCIEMAzureSleep {}

        InModuleScope Devolutions.CIEM {
            $script:AzureAuthContext = [CIEMAzureAuthContext]::new()
            $script:AzureAuthContext.IsConnected = $true
            $script:AzureAuthContext.TenantId = 'tenant-1'
            $script:AzureAuthContext.SubscriptionIds = @('sub-1')
            $script:AzureAuthContext.ARMToken = 'arm-token'
            $script:AzureAuthContext.GraphToken = 'graph-token'
            $script:AzureAuthContext.KeyVaultToken = 'kv-token'
        }
    }

    It 'Sends 20 requests in a single batch POST' {
        $script:batchSizes = [System.Collections.Generic.List[int]]::new()
        $requests = foreach ($index in 1..20) {
            @{ Id = "req-$index"; Method = 'GET'; Path = "/users/$index?`$select=id" }
        }

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            $payload = $Body | ConvertFrom-Json -AsHashtable
            $script:batchSizes.Add(@($payload.requests).Count)
            [pscustomobject]@{
                responses = @(
                    foreach ($request in @($payload.requests)) {
                        [pscustomobject]@{
                            id = $request.id
                            status = 200
                            body = [pscustomobject]@{
                                value = @([pscustomobject]@{ id = $request.id })
                            }
                        }
                    }
                )
            }
        }

        $result = Invoke-AzureApi -Api Graph -Requests $requests -ResourceName 'GraphBatch' -ErrorAction Stop

        $script:batchSizes | Should -Be @(20)
        @($result.Keys) | Should -HaveCount 20
        @($result['req-1'].Items) | Should -HaveCount 1
    }

    It 'Splits 21 requests into two batch POSTs' {
        $script:batchSizes = [System.Collections.Generic.List[int]]::new()
        $requests = foreach ($index in 1..21) {
            @{ Id = "req-$index"; Method = 'GET'; Path = "/users/$index?`$select=id" }
        }

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            $payload = $Body | ConvertFrom-Json -AsHashtable
            $script:batchSizes.Add(@($payload.requests).Count)
            [pscustomobject]@{
                responses = @(
                    foreach ($request in @($payload.requests)) {
                        [pscustomobject]@{
                            id = $request.id
                            status = 200
                            body = [pscustomobject]@{
                                value = @([pscustomobject]@{ id = $request.id })
                            }
                        }
                    }
                )
            }
        }

        $result = Invoke-AzureApi -Api Graph -Requests $requests -ResourceName 'GraphBatch' -ErrorAction Stop

        $script:batchSizes | Should -Be @(20, 1)
        @($result.Keys) | Should -HaveCount 21
    }

    It 'Throws when Requests is empty' {
        {
            Invoke-AzureApi -Api Graph -Requests @() -ResourceName 'GraphBatch' -ErrorAction Stop
        } | Should -Throw '*at least one batch request*'
    }

    It 'Retries only throttled sub-requests and preserves response IDs when the batch response is reordered' {
        $script:callCount = 0
        $script:batchSizes = [System.Collections.Generic.List[int]]::new()
        $requests = @(
            @{ Id = 'a'; Method = 'GET'; Path = '/groups/group-a/members?$select=id' }
            @{ Id = 'b'; Method = 'GET'; Path = '/groups/group-b/members?$select=id' }
        )

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            $payload = $Body | ConvertFrom-Json -AsHashtable
            $script:batchSizes.Add(@($payload.requests).Count)
            $script:callCount++

            if ($script:callCount -eq 1) {
                return [pscustomobject]@{
                    responses = @(
                        [pscustomobject]@{
                            id = 'b'
                            status = 200
                            body = [pscustomobject]@{
                                value = @([pscustomobject]@{ id = 'member-b' })
                            }
                        }
                        [pscustomobject]@{
                            id = 'a'
                            status = 429
                            headers = @{ 'Retry-After' = '3' }
                            body = [pscustomobject]@{
                                error = [pscustomobject]@{ message = 'slow down' }
                            }
                        }
                    )
                }
            }

            [pscustomobject]@{
                responses = @(
                    [pscustomobject]@{
                        id = 'a'
                        status = 200
                        body = [pscustomobject]@{
                            value = @([pscustomobject]@{ id = 'member-a' })
                        }
                    }
                )
            }
        }

        $result = Invoke-AzureApi -Api Graph -Requests $requests -ResourceName 'GraphBatch' -ErrorAction Stop

        $script:batchSizes | Should -Be @(2, 1)
        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter { $Seconds -eq 3 }
        @($result['a'].Items) | Should -HaveCount 1
        $result['a'].Items[0].id | Should -Be 'member-a'
        $result['b'].Items[0].id | Should -Be 'member-b'
    }

    It 'Returns non-throttle batch failures without failing sibling requests' {
        $requests = @(
            @{ Id = 'success'; Method = 'GET'; Path = '/groups/group-a/members?$select=id' }
            @{ Id = 'forbidden'; Method = 'GET'; Path = '/groups/group-b/members?$select=id' }
        )

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            [pscustomobject]@{
                responses = @(
                    [pscustomobject]@{
                        id = 'success'
                        status = 200
                        body = [pscustomobject]@{
                            value = @([pscustomobject]@{ id = 'member-a' })
                        }
                    }
                    [pscustomobject]@{
                        id = 'forbidden'
                        status = 403
                        body = [pscustomobject]@{
                            error = [pscustomobject]@{ message = 'denied' }
                        }
                    }
                )
            }
        }

        $result = Invoke-AzureApi -Api Graph -Requests $requests -ResourceName 'GraphBatch' -ErrorAction Stop

        $result['success'].Success | Should -BeTrue
        $result['forbidden'].Success | Should -BeFalse
        $result['forbidden'].StatusCode | Should -Be 403
    }

    It 'Aborts a batch when the wall-clock retry budget is exceeded' {
        # Set the cap very low so real wall-clock passes it before the 5-retry
        # per-request counter is exhausted. InvokeCIEMAzureSleep must REALLY sleep
        # so DateTimeOffset.UtcNow advances between iterations.
        InModuleScope Devolutions.CIEM { $script:CIEMGraphBatchWallClockSeconds = 1 }

        $requests = @(
            @{ Id = 'forever'; Method = 'GET'; Path = '/groups/group-a/members?$select=id' }
        )

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            [pscustomobject]@{
                responses = @(
                    [pscustomobject]@{
                        id = 'forever'
                        status = 429
                        headers = @{ 'Retry-After' = '2' }
                        body = [pscustomobject]@{
                            error = [pscustomobject]@{ message = 'slow down' }
                        }
                    }
                )
            }
        }

        # Let the sleep actually advance real time (capped to the wall-clock budget)
        Mock -ModuleName Devolutions.CIEM InvokeCIEMAzureSleep {
            param($Seconds)
            Start-Sleep -Milliseconds 1100
        }

        {
            Invoke-AzureApi -Api Graph -Requests $requests -ResourceName 'GraphBatch' -ErrorAction Stop
        } | Should -Throw '*wall-clock*'

        InModuleScope Devolutions.CIEM { $script:CIEMGraphBatchWallClockSeconds = 300 }
    }

    It 'Source file declares the wall-clock cap script-scope tunable' {
        $psm1Path = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psm1'
        $psm1Source = Get-Content -Path $psm1Path -Raw
        $psm1Source | Should -Match '\$script:CIEMGraphBatchWallClockSeconds\s*='
    }

    It 'Follows @odata.nextLink returned inside a batch sub-response' {
        $script:callCount = 0
        $requests = @(
            @{ Id = 'paged'; Method = 'GET'; Path = '/groups/group-a/members?$select=id' }
        )

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            if ($Uri -like '*$batch') {
                return [pscustomobject]@{
                    responses = @(
                        [pscustomobject]@{
                            id = 'paged'
                            status = 200
                            body = [pscustomobject]@{
                                value = @([pscustomobject]@{ id = 'member-1' })
                                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/groups/group-a/members?page=2'
                            }
                        }
                    )
                }
            }

            [pscustomobject]@{
                value = @([pscustomobject]@{ id = 'member-2' })
            }
        }

        $result = Invoke-AzureApi -Api Graph -Requests $requests -ResourceName 'GraphBatch' -ErrorAction Stop

        @($result['paged'].Items) | Should -HaveCount 2
        $result['paged'].Items[1].id | Should -Be 'member-2'
    }
}
