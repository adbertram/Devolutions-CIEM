BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
}

Describe 'Check data_needs' {
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
    }

    It 'Seeds Azure metadata for every local script' {
        $scriptCount = @(Get-ChildItem (Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Checks') -Filter '*.ps1').Count
        $checks = @(Get-CIEMCheck -Provider Azure)

        $checks.Count | Should -Be $scriptCount
    }

    It 'Preserves user disabled state when the catalog syncs' {
        Disable-CIEMCheck -CheckId 'entra_security_defaults_enabled'
        InModuleScope Devolutions.CIEM {
            Sync-CIEMCheckCatalog -Provider Azure
        }
        (Get-CIEMCheck -CheckId 'entra_security_defaults_enabled').Disabled | Should -BeTrue
    }

    It 'Catalog-enabled checks keep required data_needs' {
        $check = Get-CIEMCheck -CheckId 'entra_security_defaults_enabled'

        @($check.DataNeeds) | Should -Contain 'entra:securitydefaults'
    }

    It 'Disabled catalog checks can omit data_needs' {
        $check = Get-CIEMCheck -CheckId 'aks_cluster_rbac_enabled'

        $check.Disabled | Should -BeTrue
        $check.DataNeeds | Should -BeNullOrEmpty
    }

    It 'Save-CIEMCheck round-trips data_needs' {
        Save-CIEMCheck -Id 'data_needs_roundtrip' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Roundtrip' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' `
            -DataNeeds @('entra:users', 'iam:roleassignments')

        $check = Get-CIEMCheck -CheckId 'data_needs_roundtrip'

        $check | Should -Not -BeNullOrEmpty
        @($check.DataNeeds) | Should -HaveCount 2
        $check.DataNeeds[0] | Should -Be 'entra:users'
        $check.DataNeeds[1] | Should -Be 'iam:roleassignments'
    }

    It 'Update-CIEMCheck persists changed title and data_needs' {
        Update-CIEMCheck -Id 'entra_security_defaults_enabled' `
            -Title 'changed title' `
            -DataNeeds @('entra:users', 'iam:roleassignments')

        $check = Get-CIEMCheck -CheckId 'entra_security_defaults_enabled'

        $check.Title | Should -Be 'changed title'
        @($check.DataNeeds) | Should -Be @('entra:users', 'iam:roleassignments')
    }

    It 'Empty data_needs array throws at registration' {
        {
            Save-CIEMCheck -Id 'empty_data_needs' `
                -Provider 'Azure' `
                -Service 'Entra' `
                -Title 'Empty' `
                -Severity 'medium' `
                -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' `
                -DataNeeds @()
        } | Should -Throw '*must declare at least one data need*'
    }

    It 'Missing data_needs throws at scan planning' {
        Mock -ModuleName Devolutions.CIEM Sync-CIEMCheckCatalog {}

        Save-CIEMCheck -Id 'scan_missing_data_needs' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Missing' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1'

        InModuleScope Devolutions.CIEM {
            { Invoke-CIEMScan -Provider Azure -CheckId 'scan_missing_data_needs' } | Should -Throw '*missing data_needs*'
        }
    }

    It 'Fresh Azure scans no longer fail on missing metadata rows' {
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
            [pscustomobject]@{ Id = 1; Status = 'Completed' }
        }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureEntraResource { @() }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureArmResource { @() }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureResourceRelationship { @() }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMParallelForEach { @() }

        InModuleScope Devolutions.CIEM {
            { Invoke-CIEMScan -Provider Azure | Out-Null } | Should -Not -Throw
        }
    }

    It 'Planner unions data needs and fetches each slice once' {
        Mock -ModuleName Devolutions.CIEM Sync-CIEMCheckCatalog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
            [pscustomobject]@{ Id = 1; Status = 'Completed' }
        }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureEntraResource { @() }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureArmResource { @() }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMParallelForEach { @() }

        Save-CIEMCheck -Id 'union_a' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Union A' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' `
            -DataNeeds @('entra:users', 'entra:authorizationpolicy')

        Save-CIEMCheck -Id 'union_b' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Union B' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraPolicyGuestUserAccessRestriction.ps1' `
            -DataNeeds @('entra:authorizationpolicy')

        Save-CIEMCheck -Id 'union_c' `
            -Provider 'Azure' `
            -Service 'IAM' `
            -Title 'Union C' `
            -Severity 'medium' `
            -CheckScript 'Test-IamSubscriptionRolesOwnerCustomNotCreated.ps1' `
            -DataNeeds @('iam:roleassignments')

        InModuleScope Devolutions.CIEM {
            Invoke-CIEMScan -Provider Azure -CheckId @(
                'union_a',
                'union_b',
                'union_c'
            ) | Out-Null
        }

        Assert-MockCalled Get-CIEMAzureEntraResource -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter { $Type -eq 'user' }
        Assert-MockCalled Get-CIEMAzureEntraResource -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter { $Type -eq 'authorizationPolicy' }
        Assert-MockCalled Get-CIEMAzureArmResource -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter { $Type -eq 'microsoft.authorization/roleassignments' }
    }

    It 'Unknown data need throws at planning' {
        Mock -ModuleName Devolutions.CIEM Sync-CIEMCheckCatalog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
            [pscustomobject]@{ Id = 1; Status = 'Completed' }
        }

        Save-CIEMCheck -Id 'unknown_need' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Unknown Need' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' `
            -DataNeeds @('entra:bogus')

        InModuleScope Devolutions.CIEM {
            { Invoke-CIEMScan -Provider Azure -CheckId 'unknown_need' } | Should -Throw "*Unknown data need 'entra:bogus'*"
        }
    }

    It 'Data needs must use lowercase canonical form' {
        Mock -ModuleName Devolutions.CIEM Sync-CIEMCheckCatalog {}

        Save-CIEMCheck -Id 'noncanonical_need' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Noncanonical Need' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' `
            -DataNeeds @('Entra:Users')

        InModuleScope Devolutions.CIEM {
            { Invoke-CIEMScan -Provider Azure -CheckId 'noncanonical_need' } | Should -Throw "*declares non-canonical data need 'Entra:Users'*"
        }
    }

    It 'Targeted accessor uses the declared resource type filter' {
        Mock -ModuleName Devolutions.CIEM Sync-CIEMCheckCatalog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
            [pscustomobject]@{ Id = 1; Status = 'Completed' }
        }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureEntraResource { @() }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMParallelForEach { @() }

        Save-CIEMCheck -Id 'targeted_accessor' `
            -Provider 'Azure' `
            -Service 'Entra' `
            -Title 'Targeted Accessor' `
            -Severity 'medium' `
            -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' `
            -DataNeeds @('entra:users')

        InModuleScope Devolutions.CIEM {
            Invoke-CIEMScan -Provider Azure -CheckId 'targeted_accessor' | Out-Null
        }

        Assert-MockCalled Get-CIEMAzureEntraResource -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter { $Type -eq 'user' }
        Assert-MockCalled Get-CIEMAzureEntraResource -ModuleName Devolutions.CIEM -Times 0 -Exactly -ParameterFilter { $Type -ne 'user' }
    }
}
