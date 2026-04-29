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

    function New-HttpErrorRecord {
        param(
            [Parameter(Mandatory)]
            [int]$StatusCode,

            [Parameter()]
            [string]$Body,

            [Parameter()]
            [hashtable]$Headers
        )

        $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$StatusCode)
        if ($Headers) {
            foreach ($key in @($Headers.Keys)) {
                $response.Headers.TryAddWithoutValidation($key, [string]$Headers[$key]) | Out-Null
            }
        }

        $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("HTTP $StatusCode", $response)
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            "HTTP$StatusCode",
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $null
        )
        if ($Body) {
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Body)
        }

        $errorRecord
    }
}

Describe 'Invoke-AzureApi retry handling' {
    BeforeEach {
        Remove-Item "$TestDrive/ciem.db" -Force -ErrorAction SilentlyContinue
        Initialize-InfrastructureTestDatabase
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

        InModuleScope Devolutions.CIEM {
            $script:AzureAuthContext = [CIEMAzureAuthContext]::new()
            $script:AzureAuthContext.IsConnected = $true
            $script:AzureAuthContext.TenantId = 'tenant-1'
            $script:AzureAuthContext.SubscriptionIds = @('sub-1')
            $script:AzureAuthContext.ARMToken = 'arm-token'
            $script:AzureAuthContext.GraphToken = 'graph-token'
            $script:AzureAuthContext.KeyVaultToken = 'kv-token'
        }

        Mock -ModuleName Devolutions.CIEM InvokeCIEMAzureSleep {}
    }

    It 'Uses Retry-After integer header before body retryAfter' {
        $script:invokeCount = 0
        $retryError = New-HttpErrorRecord -StatusCode 429 -Body '{"retryAfter":1}' -Headers @{ 'Retry-After' = '7' }

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            $script:invokeCount++
            if ($script:invokeCount -eq 1) {
                throw $retryError
            }

            [pscustomobject]@{
                value = @([pscustomobject]@{ id = 'user-1' })
            }
        }

        $result = @(Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop)

        $result | Should -HaveCount 1
        $result[0].id | Should -Be 'user-1'
        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter { $Seconds -eq 7 }
    }

    It 'Parses Retry-After HTTP-date values' {
        $script:invokeCount = 0
        $retryAt = [DateTimeOffset]::UtcNow.AddSeconds(30).ToString('R')
        $retryError = New-HttpErrorRecord -StatusCode 429 -Headers @{ 'Retry-After' = $retryAt }

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            $script:invokeCount++
            if ($script:invokeCount -eq 1) {
                throw $retryError
            }

            [pscustomobject]@{
                value = @([pscustomobject]@{ id = 'user-2' })
            }
        }

        $result = @(Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop)

        $result[0].id | Should -Be 'user-2'
        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter {
            $Seconds -ge 25 -and $Seconds -le 30
        }
    }

    It 'Falls back to exponential backoff with jitter when Retry-After is absent' {
        $script:invokeCount = 0
        $retryError = New-HttpErrorRecord -StatusCode 429

        Mock -ModuleName Devolutions.CIEM Get-Random { 1.2 }
        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            $script:invokeCount++
            if ($script:invokeCount -eq 1) {
                throw $retryError
            }

            [pscustomobject]@{
                value = @([pscustomobject]@{ id = 'user-3' })
            }
        }

        $result = @(Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop)

        $result[0].id | Should -Be 'user-3'
        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter { $Seconds -eq 1.2 }
    }

    It 'Falls back to exponential backoff when Retry-After is malformed or non-positive' {
        $script:invokeCount = 0
        $retryError = New-HttpErrorRecord -StatusCode 429 -Body '{"retryAfter":0}' -Headers @{ 'Retry-After' = 'bogus' }

        Mock -ModuleName Devolutions.CIEM Get-Random { 0.8 }
        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            $script:invokeCount++
            if ($script:invokeCount -eq 1) {
                throw $retryError
            }

            [pscustomobject]@{
                value = @([pscustomobject]@{ id = 'user-4' })
            }
        }

        $result = @(Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop)

        $result[0].id | Should -Be 'user-4'
        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter { $Seconds -eq 0.8 }
    }

    It 'Throws without a final extra sleep when retries are exhausted' {
        $retryError = New-HttpErrorRecord -StatusCode 429 -Headers @{ 'Retry-After' = '1' }

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            throw $retryError
        }

        {
            Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop
        } | Should -Throw '*retries exhausted*'

        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 5 -Exactly
    }

    It 'Does not retry 401 responses' {
        $unauthorizedError = New-HttpErrorRecord -StatusCode 401

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            throw $unauthorizedError
        }

        {
            Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop
        } | Should -Throw '*Unauthorized*'

        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 0 -Exactly
    }

    It 'Does not retry 5xx responses' {
        $serverError = New-HttpErrorRecord -StatusCode 500 -Body '{"error":{"message":"boom"}}'

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            throw $serverError
        }

        {
            Invoke-AzureApi -Api ARM -Path '/subscriptions?api-version=2022-12-01' -ResourceName 'Subscriptions' -ErrorAction Stop
        } | Should -Throw '*Status: 500*'

        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 0 -Exactly
    }

    It 'Throws failed raw responses before returning the raw envelope' {
        $forbiddenError = New-HttpErrorRecord -StatusCode 403 -Body '{"error":{"message":"assignment delete denied"}}'

        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod {
            throw $forbiddenError
        }

        {
            Invoke-AzureApi -Api ARM -Uri 'https://management.azure.com/subscriptions/sub-1/providers/Microsoft.Authorization/roleAssignments/role-1?api-version=2022-04-01' -Method DELETE -ResourceName 'Azure RBAC role assignment role-1' -Raw -ErrorAction Stop
        } | Should -Throw '*Access denied loading Azure RBAC role assignment role-1*'

        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 0 -Exactly
    }

    It 'Caps the exponential backoff delay at 60 seconds' {
        # 2^(retry-1) exceeds 60 starting at retry 7 (2^6 = 64). Make the stub fail
        # through the full 5 retries and assert none of the sleep calls exceed 60s.
        $retryError = New-HttpErrorRecord -StatusCode 429

        Mock -ModuleName Devolutions.CIEM Get-Random { 1.2 }
        Mock -ModuleName Devolutions.CIEM Invoke-RestMethod { throw $retryError }

        {
            Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop
        } | Should -Throw '*retries exhausted*'

        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 0 -ParameterFilter { $Seconds -gt 60 }
        Assert-MockCalled InvokeCIEMAzureSleep -ModuleName Devolutions.CIEM -Times 5 -Exactly
    }

    It 'Source file uses private transport helpers instead of nested helper definitions' {
        $sourcePath = Join-Path $PSScriptRoot '..' '..' 'Public' 'Invoke-AzureApi.ps1'
        $transportPath = Join-Path $PSScriptRoot '..' '..' 'Private' 'InvokeAzureApiTransport.ps1'
        $source = Get-Content -Path $sourcePath -Raw
        $transport = Get-Content -Path $transportPath -Raw
        $source | Should -Not -Match '\bfunction\s+InvokeSafeRestMethod\b'
        $source | Should -Not -Match '\bfunction\s+GetRetryDelaySeconds\b'
        $source | Should -Not -Match '\bfunction\s+InvokeAzureRequestWithRetry\b'
        $transport | Should -Match '\bfunction\s+InvokeSafeRestMethod\b'
        $transport | Should -Match '\bfunction\s+GetRetryDelaySeconds\b'
        $transport | Should -Match '\bfunction\s+InvokeAzureRequestWithRetry\b'
        $transport | Should -Match '\bfunction\s+ConvertToHeaderMap\b'
        $transport | Should -Match '\bfunction\s+GetHeaderValue\b'
        $transport | Should -Match '\bfunction\s+GetParsedErrorMessage\b'
        $transport | Should -Match '\bfunction\s+InvokeAzureBatchRequests\b'
        $source | Should -Not -Match '\bfunction\s+Parse-ResponseContent\b'
        $source | Should -Not -Match '\bfunction\s+Invoke-SafeRestMethod\b'
    }

    It 'Source file does not silently swallow exceptions in retry-delay parsing' {
        $sourcePath = Join-Path $PSScriptRoot '..' '..' 'Public' 'Invoke-AzureApi.ps1'
        $source = Get-Content -Path $sourcePath -Raw
        # An empty catch {} block on a try inside the helpers is a fail-fast violation
        $source | Should -Not -Match '(?s)try\s*\{[^{}]{0,200}ConvertFrom-Json[^{}]{0,200}\}\s*catch\s*\{\s*\}'
    }

    It 'Source file does NOT contain the ByUri auto-Api-detection regex block' {
        $sourcePath = Join-Path $PSScriptRoot '..' '..' 'Public' 'Invoke-AzureApi.ps1'
        $source = Get-Content -Path $sourcePath -Raw
        # The auto-detect block matched the URI against host patterns to pick an API.
        $source | Should -Not -Match 'graph\\\.microsoft\\\.com/beta'
        $source | Should -Not -Match '\\.vault\\\.azure\\\.net'
    }

    It 'Source file does NOT contain a -SubscriptionId loop on the ByPath path' {
        $sourcePath = Join-Path $PSScriptRoot '..' '..' 'Public' 'Invoke-AzureApi.ps1'
        $source = Get-Content -Path $sourcePath -Raw
        # The dead-code subscription loop is gone; callers must loop at their level.
        $source | Should -Not -Match 'foreach\s*\(\s*\$subId\s+in\s+\$SubscriptionId\s*\)'
        # And the SubscriptionId parameter itself should be removed.
        $source | Should -Not -Match '\[string\[\]\]\$SubscriptionId'
    }

    It 'Source file extracts the $skipToken body mutation into a named helper' {
        $transportPath = Join-Path $PSScriptRoot '..' '..' 'Private' 'InvokeAzureApiTransport.ps1'
        $source = Get-Content -Path $transportPath -Raw
        # The extracted helper should be a no-dash VerbNoun nested function.
        $source | Should -Match '\bfunction\s+ConvertToSkipTokenBody\b'
    }

    It 'Requires -Api as a mandatory parameter' {
        # Verify via parameter metadata instead of invoking with missing param
        # (invoking leaks a "Supply values" prompt to console even non-interactively)
        $apiParam = (Get-Command Invoke-AzureApi).Parameters['Api']
        $mandatoryAttr = $apiParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
        $mandatoryAttr | Should -Not -BeNullOrEmpty -Because '-Api must be mandatory on all parameter sets'
    }
}
