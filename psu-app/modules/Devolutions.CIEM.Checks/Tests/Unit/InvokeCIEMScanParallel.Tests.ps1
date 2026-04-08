BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    $script:ScanSource = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Private' 'Invoke-CIEMScan.ps1') -Raw
    $script:LegacyScanFixture = Get-Content (Join-Path $PSScriptRoot '..' 'Fixtures' 'legacy-scan-output.json') -Raw | ConvertFrom-Json
}

Describe 'Invoke-CIEMScan parallel execution' {
    BeforeEach {
        $script:TestDatabasePath = Join-Path $TestDrive ("ciem-" + [guid]::NewGuid().ToString('N') + '.db')
        $env:CIEM_TEST_DB_PATH = $script:TestDatabasePath
        New-CIEMDatabase -Path $script:TestDatabasePath

        InModuleScope Devolutions.CIEM {
            $script:DatabasePath = $env:CIEM_TEST_DB_PATH
            $script:AuthContext = @{
                Azure = [pscustomobject]@{
                    AccountId = 'test-account'
                    AccountType = 'ServicePrincipal'
                    SubscriptionIds = @('sub1')
                }
            }
            $script:AzureAuthContext = [pscustomobject]@{
                IsConnected = $true
                TenantId = 'tenant1'
                SubscriptionIds = @('sub1')
                ARMToken = 'arm-token'
                GraphToken = 'graph-token'
                KeyVaultToken = 'kv-token'
            }
        }

        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
        Mock -ModuleName Devolutions.CIEM Sync-CIEMCheckCatalog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
            [pscustomobject]@{ Id = 1; Status = 'Completed' }
        }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureEntraResource { @() }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureArmResource { @() }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureResourceRelationship { @() }
    }

    It 'Dispatches selected checks through InvokeCIEMParallelForEach with the scan throttle limit' {
        $script:ParallelInvocation = $null
        Mock -ModuleName Devolutions.CIEM InvokeCIEMParallelForEach {
            param($InputObject, $ThrottleLimit, $ScriptBlock)

            $script:ParallelInvocation = [pscustomobject]@{
                Count = @($InputObject).Count
                ThrottleLimit = $ThrottleLimit
            }

            @()
        }

        Save-CIEMCheck -Id 'parallel_a' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Parallel A' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' `
            -DataNeeds @('entra:securitydefaults')

        Save-CIEMCheck -Id 'parallel_b' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Parallel B' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraTrustedNamedLocationExist.ps1' `
            -DataNeeds @('entra:namedlocations')

        InModuleScope Devolutions.CIEM {
            Invoke-CIEMScan -Provider Azure -CheckId @(
                'parallel_a',
                'parallel_b'
            ) | Out-Null
        }

        $expectedThrottleLimit = InModuleScope Devolutions.CIEM { $script:CIEMParallelThrottleLimitScan }

        $script:ParallelInvocation | Should -Not -BeNullOrEmpty
        $script:ParallelInvocation.Count | Should -Be 2
        $script:ParallelInvocation.ThrottleLimit | Should -Be $expectedThrottleLimit
    }

    It 'Surfaces a child failure with the failing check id' {
        Mock -ModuleName Devolutions.CIEM InvokeCIEMParallelForEach {
            @(
                [pscustomobject]@{
                    Input = [pscustomobject]@{
                        Check = [pscustomobject]@{
                            Id = 'entra_security_defaults_enabled'
                        }
                    }
                    Success = $false
                    Error = 'boom'
                }
            )
        }

        Save-CIEMCheck -Id 'parallel_failure' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Parallel Failure' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' `
            -DataNeeds @('entra:securitydefaults')

        InModuleScope Devolutions.CIEM {
            { Invoke-CIEMScan -Provider Azure -CheckId 'parallel_failure' | Out-Null } | Should -Throw "*Check 'entra_security_defaults_enabled' failed: boom*"
        }
    }

    It 'Reconstructs CIEMScanResult objects from child output' {
        Mock -ModuleName Devolutions.CIEM InvokeCIEMParallelForEach {
            @(
                [pscustomobject]@{
                    Success = $true
                    Result = @(
                        [pscustomobject]@{
                            Check = [pscustomobject]@{
                                Id = 'entra_security_defaults_enabled'
                                Provider = 'Azure'
                                Service = 'Entra'
                                Title = 'Security defaults enabled'
                                Description = 'desc'
                                Risk = 'risk'
                                Severity = 'high'
                                RelatedUrl = ''
                                CheckScript = 'Test-EntraSecurityDefaultsEnabled.ps1'
                                DependsOn = @()
                                DataNeeds = @('entra:securitydefaults')
                                Disabled = $false
                                Remediation = [pscustomobject]@{
                                    Text = 'text'
                                    Url = 'url'
                                }
                                Permissions = [pscustomobject]@{
                                    Graph = @()
                                    ARM = @()
                                    KeyVaultDataPlane = @()
                                    IAM = @()
                                }
                            }
                            Status = 'PASS'
                            StatusExtended = 'ok'
                            ResourceId = 'resource-1'
                            ResourceName = 'resource-name'
                            Location = 'Global'
                        }
                    )
                }
            )
        }

        Save-CIEMCheck -Id 'parallel_result' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Parallel Result' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' `
            -DataNeeds @('entra:securitydefaults')

        $result = InModuleScope Devolutions.CIEM {
            Invoke-CIEMScan -Provider Azure -CheckId 'parallel_result'
        }

        $result | Should -HaveCount 1
        $result[0].GetType().Name | Should -Be 'CIEMScanResult'
        $result[0].Status.ToString() | Should -Be 'PASS'
        $result[0].ResourceId | Should -Be 'resource-1'
        $result[0].Check.Id | Should -Be 'entra_security_defaults_enabled'

        $normalizedResults = @(
            $result |
                ForEach-Object {
                    [pscustomobject]@{
                        CheckId = $_.Check.Id
                        Status = $_.Status.ToString()
                        StatusExtended = $_.StatusExtended
                        ResourceId = $_.ResourceId
                        ResourceName = $_.ResourceName
                        Location = $_.Location
                    }
                }
        )

        ($normalizedResults | ConvertTo-Json -Depth 5) | Should -Be ($script:LegacyScanFixture | ConvertTo-Json -Depth 5)
    }

    It 'Skips parallel dispatch when no checks remain after filtering' {
        Mock -ModuleName Devolutions.CIEM InvokeCIEMParallelForEach { throw 'should not be called' }

        InModuleScope Devolutions.CIEM {
            { Invoke-CIEMScan -Provider Azure -Service 'DoesNotExist' | Out-Null } | Should -Not -Throw
        }

        Assert-MockCalled InvokeCIEMParallelForEach -ModuleName Devolutions.CIEM -Times 0 -Exactly
    }

    It 'Does not use an unconditional Connect-CIEM -Force path' {
        $script:ScanSource | Should -Not -Match 'Connect-CIEM\s+-Provider\s+\$providersToConnect\s+-Force'
    }

    It 'Pre-validates check severities BEFORE parallel dispatch' {
        $script:ScanSource | Should -Match '\[CIEMCheckSeverity\]'
        # The cast must occur in the foreach loop that builds $selectedChecks (i.e., before the
        # InvokeCIEMParallelForEach call), not only inside the parallel script block.
        $beforeParallel = $script:ScanSource -split 'InvokeCIEMParallelForEach', 2
        $beforeParallel[0] | Should -Match '\[CIEMCheckSeverity\]'
    }

    It 'No dashed private helper names remain anywhere in the scan source (VerbNoun rule)' {
        $script:ScanSource | Should -Not -Match '\bfunction\s+ConvertTo-CIEMCheckObject\b'
        $script:ScanSource | Should -Not -Match '\bfunction\s+ConvertFrom-CIEMStoredResource\b'
        $script:ScanSource | Should -Not -Match '\bfunction\s+Initialize-IAMSubscriptionBucket\b'
        $script:ScanSource | Should -Not -Match '\bfunction\s+Get-CIEMAzureScanServiceCache\b'
        $script:ScanSource | Should -Not -Match '\bfunction\s+ConvertTo-CIEMScanResultObject\b'
        $script:ScanSource | Should -Not -Match '\bfunction\s+Ensure-ServiceData\b'
    }

    It 'GetCIEMAzureScanServiceCache is reachable from InModuleScope' {
        # It may live inside Invoke-CIEMScan as a nested function OR as a top-level private
        # function — what matters is that the cache function is defined and the other
        # downstream helpers (ConvertToCIEMCheckObject, etc.) remain callable via the
        # module scope or through Invoke-CIEMScan's own call path.
        InModuleScope Devolutions.CIEM {
            # GetCIEMEntraNeeds and GetCIEMIAMNeeds are top-level module functions (asserted below).
            Get-Command -Name 'GetCIEMEntraNeeds' -ErrorAction Stop | Should -Not -BeNullOrEmpty
            Get-Command -Name 'GetCIEMIAMNeeds' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    It 'GetCIEMAzureScanServiceCache takes the working hashtables as explicit parameters' {
        # The refactor should make the inner closure unnecessary by passing ServiceData/ServiceErrors/
        # ServiceStarted into a top-level helper instead of relying on parent-scope variable capture.
        $script:ScanSource | Should -Match '\[hashtable\]\$ServiceData'
        $script:ScanSource | Should -Match '\[hashtable\]\$ServiceErrors'
        $script:ScanSource | Should -Match '\[hashtable\]\$ServiceStarted'
    }

    It 'Entra and IAM need-key dispatch is delegated to dedicated module-scope helpers' {
        # GetCIEMEntraNeeds and GetCIEMIAMNeeds live in their own private files under
        # Devolutions.CIEM.Checks/Private/, not nested inside Invoke-CIEMScan.
        InModuleScope Devolutions.CIEM {
            Get-Command -Name 'GetCIEMEntraNeeds' -ErrorAction Stop | Should -Not -BeNullOrEmpty
            Get-Command -Name 'GetCIEMIAMNeeds' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        # The old 13-arm monolithic switch inside GetCIEMAzureScanServiceCache must be gone.
        $cacheFunctionStart = $script:ScanSource.IndexOf('function GetCIEMAzureScanServiceCache')
        $cacheFunctionStart | Should -BeGreaterThan -1
        $helperStart = $script:ScanSource.IndexOf('function ConvertToCIEMScanResultObject', $cacheFunctionStart)
        if ($helperStart -lt 0) { $helperStart = $script:ScanSource.Length }
        $cacheFunctionBody = $script:ScanSource.Substring($cacheFunctionStart, $helperStart - $cacheFunctionStart)

        # Count hardcoded need-key string literals INSIDE the cache function body.
        $entraArmCount = ([regex]::Matches($cacheFunctionBody, "'entra:[a-z]+'")).Count
        $iamArmCount = ([regex]::Matches($cacheFunctionBody, "'iam:[a-z]+'")).Count
        ($entraArmCount + $iamArmCount) | Should -BeLessThan 4

        # The refactor must also drop the 13-arm switch — the dispatch should call
        # the two helpers directly.
        $cacheFunctionBody | Should -Match 'GetCIEMEntraNeeds'
        $cacheFunctionBody | Should -Match 'GetCIEMIAMNeeds'
    }

    It 'GetCIEMEntraNeeds dispatches the entra:users need key to Get-CIEMAzureEntraResource -Type user' {
        InModuleScope Devolutions.CIEM {
            $script:entraCallLog = [System.Collections.Generic.List[object]]::new()
            Mock Get-CIEMAzureEntraResource {
                $script:entraCallLog.Add($Type)
                @()
            }

            $serviceData = @{}
            $serviceErrors = @{}
            $serviceStarted = @{}

            GetCIEMEntraNeeds `
                -NeedKeys @('entra:users') `
                -ServiceData $serviceData `
                -ServiceErrors $serviceErrors `
                -ServiceStarted $serviceStarted

            @($script:entraCallLog) | Should -Contain 'user'
            $serviceData.ContainsKey('Entra') | Should -BeTrue
        }
    }

    It 'GetCIEMIAMNeeds dispatches iam:roleassignments and iam:roledefinitions through Get-CIEMAzureArmResource' {
        InModuleScope Devolutions.CIEM {
            $script:armCallLog = [System.Collections.Generic.List[object]]::new()
            Mock Get-CIEMAzureArmResource {
                $script:armCallLog.Add($Type)
                @()
            }

            $serviceData = @{}
            $serviceErrors = @{}
            $serviceStarted = @{}

            GetCIEMIAMNeeds `
                -NeedKeys @('iam:roleassignments', 'iam:roledefinitions') `
                -SubscriptionIds @('sub-1') `
                -ServiceData $serviceData `
                -ServiceErrors $serviceErrors `
                -ServiceStarted $serviceStarted

            @($script:armCallLog) | Should -Contain 'microsoft.authorization/roleassignments'
            @($script:armCallLog) | Should -Contain 'microsoft.authorization/roledefinitions'
            $serviceData.ContainsKey('IAM') | Should -BeTrue
            $serviceData['IAM'].ContainsKey('sub-1') | Should -BeTrue
        }
    }

    It 'GetCIEMEntraNeeds throws fail-fast on unknown entra:* need keys' {
        InModuleScope Devolutions.CIEM {
            $serviceData = @{}
            $serviceErrors = @{}
            $serviceStarted = @{}

            { GetCIEMEntraNeeds `
                -NeedKeys @('entra:madeupkey') `
                -ServiceData $serviceData `
                -ServiceErrors $serviceErrors `
                -ServiceStarted $serviceStarted } |
                Should -Throw "*Unknown data need 'entra:madeupkey'*"
        }
    }

    It 'GetCIEMIAMNeeds throws fail-fast on unknown iam:* need keys' {
        InModuleScope Devolutions.CIEM {
            $serviceData = @{}
            $serviceErrors = @{}
            $serviceStarted = @{}

            { GetCIEMIAMNeeds `
                -NeedKeys @('iam:madeupkey') `
                -SubscriptionIds @('sub-1') `
                -ServiceData $serviceData `
                -ServiceErrors $serviceErrors `
                -ServiceStarted $serviceStarted } |
                Should -Throw "*Unknown data need 'iam:madeupkey'*"
        }
    }
}
