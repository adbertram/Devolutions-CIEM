BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    function New-TestCheckObject {
        param(
            [Parameter(Mandatory)]
            [string]$Id,

            [Parameter(Mandatory)]
            [string]$CheckScript,

            [Parameter()]
            [string]$Service = 'Entra',

            [Parameter()]
            [AllowNull()]
            [string[]]$DataNeeds
        )

        [PSCustomObject]@{
            Id              = $Id
            Provider        = 'Azure'
            Service         = $Service
            Title           = $Id
            Description     = 'test'
            Risk            = 'test'
            Severity        = 'medium'
            RelatedUrl      = ''
            CheckScript     = $CheckScript
            ExecutionMode   = 'script'
            ManualReason    = $null
            Evaluator       = $null
            EvaluatorConfig = $null
            DependsOn       = @()
            DataNeeds       = $DataNeeds
            Disabled        = $false
            Remediation     = [PSCustomObject]@{
                Text = 'test'
                Url  = ''
            }
            Permissions     = [PSCustomObject]@{
                Graph             = @()
                ARM               = @()
                KeyVaultDataPlane = @()
                IAM               = @()
            }
        }
    }
}

Describe 'Check data_needs' {
    BeforeEach {
        $script:TestDatabasePath = Join-Path $TestDrive ("ciem-" + [guid]::NewGuid().ToString('N') + '.db')
        $env:CIEM_TEST_DB_PATH = $script:TestDatabasePath
        New-CIEMDatabase -Path $script:TestDatabasePath

        InModuleScope Devolutions.CIEM {
            $script:DatabasePath = $env:CIEM_TEST_DB_PATH
        }

        $azureSchemaPath = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Infrastructure' 'Data' 'azure_schema.sql'
        $discoverySchemaPath = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Discovery' 'Data' 'discovery_schema.sql'
        foreach ($schemaPath in @($azureSchemaPath, $discoverySchemaPath)) {
            foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
                Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
            }
        }

        InModuleScope Devolutions.CIEM {
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

    It 'Seeds Azure metadata for every catalog row' {
        $catalog = @(
            Get-Content (Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Checks' 'check_catalog.json') -Raw |
                ConvertFrom-Json
        )
        $checks = @(Get-CIEMCheck -Provider Azure)

        $checks.Count | Should -Be $catalog.Count
    }

    It 'Preserves user disabled state when the catalog syncs' {
        Disable-CIEMCheck -CheckId 'entra_security_defaults_enabled'
        InModuleScope Devolutions.CIEM {
            SyncCIEMCheckCatalog -Provider Azure
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

    It 'Save-CIEMCheck rejects static data_needs metadata writes' {
        {
            Save-CIEMCheck -InputObject ([PSCustomObject]@{
                Id        = 'entra_security_defaults_enabled'
                DataNeeds = @()
            })
        } | Should -Throw '*Only disabled state can be updated*'
    }

    It 'Update-CIEMCheck rejects changed title and data_needs metadata' {
        {
            Update-CIEMCheck -Id 'entra_security_defaults_enabled' `
                -Title 'changed title' `
                -DataNeeds @('entra:users', 'iam:roleassignments')
        } | Should -Throw '*Only disabled state can be updated*'

        $check = Get-CIEMCheck -CheckId 'entra_security_defaults_enabled'

        $check.Title | Should -Be 'Microsoft Entra ID tenant has Security Defaults enabled'
        @($check.DataNeeds) | Should -Be @('entra:securitydefaults')
    }

    It 'Missing data_needs throws at scan planning' {
        Mock -ModuleName Devolutions.CIEM SyncCIEMCheckCatalog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMCheck {
            New-TestCheckObject -Id 'scan_missing_data_needs' -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' -DataNeeds $null
        }

        InModuleScope Devolutions.CIEM {
            { InvokeCIEMScan -Provider Azure -CheckId 'scan_missing_data_needs' } | Should -Throw '*missing data_needs*'
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
            { InvokeCIEMScan -Provider Azure | Out-Null } | Should -Not -Throw
        }
    }

    It 'Planner unions data needs and fetches each slice once' {
        Mock -ModuleName Devolutions.CIEM SyncCIEMCheckCatalog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
            [pscustomobject]@{ Id = 1; Status = 'Completed' }
        }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureEntraResource { @() }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureArmResource { @() }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMParallelForEach { @() }
        Mock -ModuleName Devolutions.CIEM Get-CIEMCheck {
            @(
                New-TestCheckObject -Id 'union_a' -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' -DataNeeds @('entra:users', 'entra:authorizationpolicy')
                New-TestCheckObject -Id 'union_b' -CheckScript 'Test-EntraPolicyGuestUserAccessRestriction.ps1' -DataNeeds @('entra:authorizationpolicy')
                New-TestCheckObject -Id 'union_c' -Service 'IAM' -CheckScript 'Test-IamSubscriptionRolesOwnerCustomNotCreated.ps1' -DataNeeds @('iam:roleassignments')
            )
        }

        InModuleScope Devolutions.CIEM {
            InvokeCIEMScan -Provider Azure -CheckId @(
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
        Mock -ModuleName Devolutions.CIEM SyncCIEMCheckCatalog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
            [pscustomobject]@{ Id = 1; Status = 'Completed' }
        }
        Mock -ModuleName Devolutions.CIEM Get-CIEMCheck {
            New-TestCheckObject -Id 'unknown_need' -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' -DataNeeds @('entra:bogus')
        }

        InModuleScope Devolutions.CIEM {
            { InvokeCIEMScan -Provider Azure -CheckId 'unknown_need' } | Should -Throw "*Unknown data need 'entra:bogus'*"
        }
    }

    It 'Data needs must use lowercase canonical form' {
        Mock -ModuleName Devolutions.CIEM SyncCIEMCheckCatalog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMCheck {
            New-TestCheckObject -Id 'noncanonical_need' -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' -DataNeeds @('Entra:Users')
        }

        InModuleScope Devolutions.CIEM {
            { InvokeCIEMScan -Provider Azure -CheckId 'noncanonical_need' } | Should -Throw "*declares non-canonical data need 'Entra:Users'*"
        }
    }

    It 'Targeted accessor uses the declared resource type filter' {
        Mock -ModuleName Devolutions.CIEM SyncCIEMCheckCatalog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
            [pscustomobject]@{ Id = 1; Status = 'Completed' }
        }
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureEntraResource { @() }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMParallelForEach { @() }
        Mock -ModuleName Devolutions.CIEM Get-CIEMCheck {
            New-TestCheckObject -Id 'targeted_accessor' -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1' -DataNeeds @('entra:users')
        }

        InModuleScope Devolutions.CIEM {
            InvokeCIEMScan -Provider Azure -CheckId 'targeted_accessor' | Out-Null
        }

        Assert-MockCalled Get-CIEMAzureEntraResource -ModuleName Devolutions.CIEM -Times 1 -Exactly -ParameterFilter { $Type -eq 'user' }
        Assert-MockCalled Get-CIEMAzureEntraResource -ModuleName Devolutions.CIEM -Times 0 -Exactly -ParameterFilter { $Type -ne 'user' }
    }
}
