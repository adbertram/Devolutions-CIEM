BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    function Initialize-StreamingDiscoveryTestDatabase {
        New-CIEMDatabase -Path "$TestDrive/ciem.db"

        InModuleScope Devolutions.CIEM {
            $script:DatabasePath = "$TestDrive/ciem.db"
        }

        foreach ($schemaPath in @(
            (Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'),
            (Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'),
            (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.Graph' 'Data' 'graph_schema.sql')
        )) {
            foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
                $trimmed = $statement.Trim()
                try {
                    Invoke-CIEMQuery -Query $trimmed -AsNonQuery | Out-Null
                }
                catch {
                    if ($trimmed -match 'ALTER\s+TABLE' -and $_.Exception.Message -match 'duplicate column') {
                        continue
                    }
                    throw
                }
            }
        }
    }
}

Describe 'Start-CIEMAzureDiscovery streaming writes' {
    BeforeEach {
        Remove-Item "$TestDrive/ciem.db" -Force -ErrorAction SilentlyContinue
        Initialize-StreamingDiscoveryTestDatabase
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
        Mock -ModuleName Devolutions.CIEM Write-Progress {}

        InModuleScope Devolutions.CIEM {
            $script:AzureAuthContext = [CIEMAzureAuthContext]::new()
            $script:AzureAuthContext.IsConnected = $true
            $script:AzureAuthContext.TenantId = 'tenant-1'
            $script:AzureAuthContext.SubscriptionIds = @('sub-1')
            $script:AzureAuthContext.ARMToken = 'arm-token'
            $script:AzureAuthContext.GraphToken = 'graph-token'
            $script:AzureAuthContext.KeyVaultToken = 'kv-token'
            $script:AuthContext = @{
                Azure = $script:AzureAuthContext
            }
        }

        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun { @() }
        Mock -ModuleName Devolutions.CIEM New-CIEMAzureDiscoveryRun {
            [pscustomobject]@{ Id = 1; Scope = $Scope; Status = $Status }
        }
        Mock -ModuleName Devolutions.CIEM Update-CIEMAzureDiscoveryRun {
            [pscustomobject]@{
                Id = $Id
                Status = $Status
                ArmRowCount = $ArmRowCount
                EntraRowCount = $EntraRowCount
                WarningCount = $WarningCount
                ErrorMessage = $ErrorMessage
            }
        }
        Mock -ModuleName Devolutions.CIEM GetCIEMBuiltInRoleDefinitions { @() }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMGraphNodeBuild { 0 }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMGraphEdgeBuild { 0 }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMGraphComputedEdgeBuild { 0 }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMAzureEffectiveRoleAssignmentBuild { 0 }
    }

    It 'Commits ARM rows before Entra collection starts' {
        $script:armSeenBeforeEntra = $false

        Mock -ModuleName Devolutions.CIEM InvokeCIEMResourceGraphQuery {
            @(
                [pscustomobject]@{
                    Id = '/subscriptions/sub-1/resourceGroups/rg-1/providers/Microsoft.Compute/virtualMachines/vm-1'
                    Type = 'microsoft.compute/virtualmachines'
                    Name = 'vm-1'
                    ResourceGroup = 'rg-1'
                    SubscriptionId = 'sub-1'
                    TenantId = 'tenant-1'
                    CollectedAt = '2026-01-01T00:00:00Z'
                    LastSeenAt = 0
                }
            )
        }

        Mock -ModuleName Devolutions.CIEM InvokeCIEMEntraEntityCollection {
            $count = @(Get-CIEMAzureArmResource).Count
            if ($count -eq 1) {
                $script:armSeenBeforeEntra = $true
            }

            @(
                [pscustomobject]@{
                    Id = 'user-1'
                    Type = 'user'
                    DisplayName = 'User 1'
                    CollectedAt = '2026-01-01T00:00:00Z'
                    LastSeenAt = 0
                }
            )
        }

        Mock -ModuleName Devolutions.CIEM InvokeCIEMEntraPermissionCollection { @() }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMEntraRelationshipCollection { @() }

        $run = Start-CIEMAzureDiscovery -Scope All

        $script:armSeenBeforeEntra | Should -BeTrue
        $run.Status | Should -Be 'Completed'
        @(Get-CIEMAzureArmResource) | Should -HaveCount 1
    }

    It 'Keeps committed ARM rows when the Entra phase fails' {
        Mock -ModuleName Devolutions.CIEM InvokeCIEMResourceGraphQuery {
            @(
                [pscustomobject]@{
                    Id = '/subscriptions/sub-1/resourceGroups/rg-1/providers/Microsoft.Compute/virtualMachines/vm-1'
                    Type = 'microsoft.compute/virtualmachines'
                    Name = 'vm-1'
                    ResourceGroup = 'rg-1'
                    SubscriptionId = 'sub-1'
                    TenantId = 'tenant-1'
                    CollectedAt = '2026-01-01T00:00:00Z'
                    LastSeenAt = 0
                }
            )
        }

        Mock -ModuleName Devolutions.CIEM InvokeCIEMEntraEntityCollection {
            throw 'entra failed'
        }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMEntraPermissionCollection { @() }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMEntraRelationshipCollection { @() }

        $run = Start-CIEMAzureDiscovery -Scope All

        $run.Status | Should -Be 'Partial'
        @(Get-CIEMAzureArmResource) | Should -HaveCount 1
    }
}
