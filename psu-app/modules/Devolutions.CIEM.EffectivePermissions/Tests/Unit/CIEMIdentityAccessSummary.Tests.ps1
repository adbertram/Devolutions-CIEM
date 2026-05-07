BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Discovery' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    $graphSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Devolutions.CIEM.Graph' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $graphSchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    $script:NewTestCIEMAzurePermissionJson = {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [string[]]$Actions,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [string[]]$DataActions
        )

        @(
            @{
                actions = @($Actions)
                notActions = @()
                dataActions = @($DataActions)
                notDataActions = @()
            }
        ) | ConvertTo-Json -Depth 5 -Compress
    }
}

Describe 'Get-CIEMIdentityAccessSummary' {

    Context 'Command contract' {

        It 'Is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMIdentityAccessSummary -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when one principal has access to multiple targets' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            $identityProps = @{
                accountEnabled = $true
                daysSinceSignIn = 12
                lastSignIn = '2026-04-25T14:00:00Z'
                lastInteractiveSignIn = '2026-04-25T14:00:00Z'
                lastNonInteractiveSignIn = $null
            } | ConvertTo-Json -Compress

            Save-CIEMGraphNode -Id 'principal-shared' -Kind 'EntraUser' -DisplayName 'Shared Identity' -Provider 'azure' -Properties $identityProps
            Save-CIEMGraphNode -Id '/subscriptions/sub-summary/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/vault-summary' `
                -Kind 'AzureKeyVault' `
                -DisplayName 'Summary Key Vault' `
                -Provider 'azure' `
                -Properties '{"arm_type":"microsoft.keyvault/vaults"}'
            Save-CIEMGraphNode -Id '/subscriptions/sub-summary' -Kind 'AzureSubscription' -DisplayName 'Summary Subscription' -Provider 'azure'

            $readerPermissions = & $script:NewTestCIEMAzurePermissionJson `
                -Actions @('Microsoft.KeyVault/vaults/read') `
                -DataActions @()

            $ownerPermissions = & $script:NewTestCIEMAzurePermissionJson `
                -Actions @('*') `
                -DataActions @()

            Save-CIEMGraphEdge -SourceId 'principal-shared' -TargetId '/subscriptions/sub-summary/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/vault-summary' -Kind 'HasRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Key Vault Reader'
                    role_definition_id = 'role-kv-reader'
                    permissions_json = $readerPermissions
                    privileged = $false
                    principal_type = 'User'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'principal-shared' -TargetId '/subscriptions/sub-summary' -Kind 'HasRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Owner'
                    role_definition_id = 'role-owner'
                    permissions_json = $ownerPermissions
                    privileged = $true
                    principal_type = 'User'
                    scope = '/subscriptions/sub-summary'
                } | ConvertTo-Json -Compress)

            $script:summary = @(Get-CIEMIdentityAccessSummary -Provider Azure)
        }

        It 'Returns one top-level row for the principal' {
            $script:summary | Should -HaveCount 1
            $script:summary[0].PrincipalId | Should -Be 'principal-shared'
        }

        It 'Exposes ObjectId and PrincipalId for disambiguation' {
            $script:summary[0].ObjectId | Should -Be 'principal-shared'
            $script:summary[0].PrincipalId | Should -Be 'principal-shared'
        }

        It 'Summarizes entitlement, privileged, effective permission, and target counts' {
            $script:summary[0].EntitlementCount | Should -Be 2
            $script:summary[0].PrivilegedRoleCount | Should -Be 1
            $script:summary[0].EffectivePermissionCount | Should -Be 2
            $script:summary[0].TargetCount | Should -Be 2
        }

        It 'Preserves the identity risk summary on the grouped row' {
            $script:summary[0].RiskLevel | Should -Be 'High'
            $script:summary[0].LastActivity | Should -Be '2026-04-25T14:00:00Z'
        }
    }

    Context 'when distinct principals share a display name' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'sp-duplicate-name' -Kind 'EntraServicePrincipal' -DisplayName 'Duplicate App' -Provider 'azure'
            Save-CIEMGraphNode -Id 'mi-duplicate-name' -Kind 'EntraManagedIdentity' -DisplayName 'Duplicate App' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub-duplicate' -Kind 'AzureSubscription' -DisplayName 'Duplicate Subscription' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId 'sp-duplicate-name' -TargetId '/subscriptions/sub-duplicate' -Kind 'HasRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Reader'
                    role_definition_id = 'reader'
                    permissions_json = $null
                    privileged = $false
                    principal_type = 'ServicePrincipal'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'mi-duplicate-name' -TargetId '/subscriptions/sub-duplicate' -Kind 'HasRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Owner'
                    role_definition_id = 'owner'
                    permissions_json = $null
                    privileged = $true
                    principal_type = 'ManagedIdentity'
                    scope = '/subscriptions/sub-duplicate'
                } | ConvertTo-Json -Compress)

            $script:summary = @(Get-CIEMIdentityAccessSummary -Provider Azure)
        }

        It 'Keeps distinct principals as separate identity rows keyed by ObjectId' {
            $script:summary | Should -HaveCount 2
            $script:summary.ObjectId | Should -Contain 'sp-duplicate-name'
            $script:summary.ObjectId | Should -Contain 'mi-duplicate-name'
        }

        It 'Shows principal type alongside the duplicate display name' {
            ($script:summary | Where-Object { $_.ObjectId -eq 'sp-duplicate-name' }).PrincipalType | Should -Be 'ServicePrincipal'
            ($script:summary | Where-Object { $_.ObjectId -eq 'mi-duplicate-name' }).PrincipalType | Should -Be 'ManagedIdentity'
        }
    }

    Context 'when filters are applied' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'principal-reader' -Kind 'EntraUser' -DisplayName 'Reader Principal' -Provider 'azure'
            Save-CIEMGraphNode -Id 'principal-owner' -Kind 'EntraUser' -DisplayName 'Owner Principal' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub-filter-summary' -Kind 'AzureSubscription' -DisplayName 'Filter Subscription' -Provider 'azure'

            $readerPermissions = & $script:NewTestCIEMAzurePermissionJson `
                -Actions @('Microsoft.Resources/subscriptions/read') `
                -DataActions @()

            Save-CIEMGraphEdge -SourceId 'principal-reader' -TargetId '/subscriptions/sub-filter-summary' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Reader'; role_definition_id = 'reader'; permissions_json = $readerPermissions; privileged = $false; principal_type = 'User' } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'principal-owner' -TargetId '/subscriptions/sub-filter-summary' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; role_definition_id = 'owner'; permissions_json = $null; privileged = $true; principal_type = 'User'; scope = '/subscriptions/sub-filter-summary' } | ConvertTo-Json -Compress)

            $script:privileged = @(Get-CIEMIdentityAccessSummary -Provider Azure -PrivilegedOnly)
            $script:readAccess = @(Get-CIEMIdentityAccessSummary -Provider Azure -AccessLevel Read)
        }

        It 'Returns only principals with matching privileged access when PrivilegedOnly is specified' {
            $script:privileged | Should -HaveCount 1
            $script:privileged[0].PrincipalId | Should -Be 'principal-owner'
        }

        It 'Returns only principals with matching access level when AccessLevel is specified' {
            $script:readAccess | Should -HaveCount 1
            $script:readAccess[0].PrincipalId | Should -Be 'principal-reader'
        }
    }
}
