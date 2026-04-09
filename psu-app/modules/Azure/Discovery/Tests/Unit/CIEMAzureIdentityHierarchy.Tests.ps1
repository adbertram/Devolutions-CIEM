BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    foreach ($schemaPath in @(
        (Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'),
        (Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql')
    )) {
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    }
}

Describe 'ResolveCIEMScopeLabel' {

    It 'Is available as a private function inside the module' {
        InModuleScope Devolutions.CIEM {
            Get-Command ResolveCIEMScopeLabel -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Scope string parsing' {
        It 'Resolves subscription scope to friendly name when lookup contains it' {
            InModuleScope Devolutions.CIEM {
                $lookup = @{ 'sub-abc' = 'Visual Studio Enterprise' }
                $result = ResolveCIEMScopeLabel -Scope '/subscriptions/sub-abc' -SubscriptionNameLookup $lookup
                $result | Should -Be 'Visual Studio Enterprise (subscription)'
            }
        }

        It 'Falls back to subscription ID when name not in lookup' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMScopeLabel -Scope '/subscriptions/sub-xyz' -SubscriptionNameLookup @{}
                $result | Should -Be 'sub-xyz (subscription)'
            }
        }

        It 'Resolves resource group scope' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMScopeLabel -Scope '/subscriptions/sub-abc/resourceGroups/rg-web' -SubscriptionNameLookup @{}
                $result | Should -Be 'rg-web (resource group)'
            }
        }

        It 'Resolves resource scope to resource name' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMScopeLabel -Scope '/subscriptions/sub-abc/resourceGroups/rg-web/providers/Microsoft.Compute/virtualMachines/vm-prod' -SubscriptionNameLookup @{}
                $result | Should -Be 'vm-prod'
            }
        }

        It 'Resolves root scope' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMScopeLabel -Scope '/' -SubscriptionNameLookup @{}
                $result | Should -Be 'Root Scope'
            }
        }

        It 'Returns last path segment for unknown scope format' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMScopeLabel -Scope '/providers/Microsoft.Management/managementGroups/mg-corp' -SubscriptionNameLookup @{}
                $result | Should -Be 'mg-corp'
            }
        }
    }
}

Describe 'Get-CIEMAzureIdentityHierarchy' {

    Context 'Command structure' {
        It 'Is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureIdentityHierarchy -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has -Mode parameter with ValidateSet Effective,Direct' {
            $cmd = Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureIdentityHierarchy
            $modeParam = $cmd.Parameters['Mode']
            $modeParam | Should -Not -BeNullOrEmpty
            $validateSet = $modeParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Effective'
            $validateSet.ValidValues | Should -Contain 'Direct'
        }

        It 'Has -SubscriptionId parameter' {
            $cmd = Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureIdentityHierarchy
            $cmd.Parameters['SubscriptionId'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'No data' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
        }

        It 'Throws when no effective role assignments exist (Effective mode)' {
            { Get-CIEMAzureIdentityHierarchy -Mode Effective } | Should -Throw
        }

        It 'Throws when no role assignment ARM resources exist (Direct mode)' {
            { Get-CIEMAzureIdentityHierarchy -Mode Direct } | Should -Throw
        }
    }

    Context 'Effective mode — 2 users, 1 group, 3 role assignments' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"

            # Seed subscription name lookup
            Save-CIEMAzureArmResource -Id '/subscriptions/sub1' `
                -Type 'microsoft.resources/subscriptions' -Name 'Visual Studio Enterprise' `
                -SubscriptionId 'sub1' -TenantId 'tenant1'

            # Seed effective role assignments
            # User1: direct Contributor on a resource
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user1-id' -PrincipalType 'User' `
                -PrincipalDisplayName 'John Smith' `
                -OriginalPrincipalId 'user1-id' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'roledef-contributor' -RoleName 'Contributor' `
                -Scope '/subscriptions/sub1/resourceGroups/rg-web/providers/Microsoft.Compute/virtualMachines/vm-prod' `
                -ComputedAt '2026-03-16T00:00:00Z'

            # User1: inherited Owner via group
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user1-id' -PrincipalType 'User' `
                -PrincipalDisplayName 'John Smith' `
                -OriginalPrincipalId 'group1-id' -OriginalPrincipalType 'Group' `
                -RoleDefinitionId 'roledef-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub1' `
                -ComputedAt '2026-03-16T00:00:00Z'

            # User2: direct Reader on subscription
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user2-id' -PrincipalType 'User' `
                -PrincipalDisplayName 'Jane Doe' `
                -OriginalPrincipalId 'user2-id' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'roledef-reader' -RoleName 'Reader' `
                -Scope '/subscriptions/sub1' `
                -ComputedAt '2026-03-16T00:00:00Z'

            # Group1: direct Owner on subscription (the group itself)
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'group1-id' -PrincipalType 'Group' `
                -PrincipalDisplayName 'Cloud Admins' `
                -OriginalPrincipalId 'group1-id' -OriginalPrincipalType 'Group' `
                -RoleDefinitionId 'roledef-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub1' `
                -ComputedAt '2026-03-16T00:00:00Z'

            # Seed Entra resource for group name lookup (used by annotation)
            Save-CIEMAzureEntraResource -Id 'group1-id' -Type 'group' `
                -DisplayName 'Cloud Admins'

            $script:effectiveResult = @(Get-CIEMAzureIdentityHierarchy -Mode Effective)
        }

        It 'Returns PSCustomObject array' {
            $script:effectiveResult | Should -Not -BeNullOrEmpty
            $script:effectiveResult[0] | Should -BeOfType [PSCustomObject]
        }

        It 'Contains exactly one Tenant node at Depth 0' {
            $tenants = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Tenant' })
            $tenants | Should -HaveCount 1
            $tenants[0].Depth | Should -Be 0
        }

        It 'Contains IdentityType nodes for User and Group at Depth 1' {
            $types = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'IdentityType' })
            $types | Should -Not -BeNullOrEmpty
            $labels = $types | Select-Object -ExpandProperty Label
            # User and Group should both appear (labels contain counts)
            ($labels -join ',') | Should -Match 'User'
            ($labels -join ',') | Should -Match 'Group'
            $types | ForEach-Object { $_.Depth | Should -Be 1 }
        }

        It 'Contains Identity nodes at Depth 2' {
            $identities = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Identity' })
            $identities | Should -Not -BeNullOrEmpty
            $identities | ForEach-Object { $_.Depth | Should -Be 2 }
        }

        It 'Contains 3 distinct identities (John Smith, Jane Doe, Cloud Admins)' {
            $identities = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Identity' })
            $identities | Should -HaveCount 3
            $labels = $identities | Select-Object -ExpandProperty Label
            $labels | Should -Contain 'John Smith'
            $labels | Should -Contain 'Jane Doe'
            $labels | Should -Contain 'Cloud Admins'
        }

        It 'Contains Role nodes at Depth 3' {
            $roles = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Role' })
            $roles | Should -Not -BeNullOrEmpty
            $roles | ForEach-Object { $_.Depth | Should -Be 3 }
        }

        It 'Contains Scope nodes at Depth 4' {
            $scopes = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Scope' })
            $scopes | Should -Not -BeNullOrEmpty
            $scopes | ForEach-Object { $_.Depth | Should -Be 4 }
        }

        It 'Annotates inherited assignments with group name' {
            # User1 has Owner via group1-id (Cloud Admins) — scope label should contain "via"
            $user1Identity = $script:effectiveResult | Where-Object { $_.NodeType -eq 'Identity' -and $_.Label -eq 'John Smith' }
            $user1NodeId = $user1Identity.NodeId
            $user1Roles = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Role' -and $_.ParentNodeId -eq $user1NodeId })
            $ownerRole = $user1Roles | Where-Object { $_.Label -match 'Owner' }
            $ownerRole | Should -Not -BeNullOrEmpty
            $ownerScopes = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Scope' -and $_.ParentNodeId -eq $ownerRole.NodeId })
            ($ownerScopes.Label -join ',') | Should -Match 'via Cloud Admins'
        }

        It 'Does not annotate direct assignments' {
            # User1 has direct Contributor — no "via" in scope label
            $user1Identity = $script:effectiveResult | Where-Object { $_.NodeType -eq 'Identity' -and $_.Label -eq 'John Smith' }
            $user1NodeId = $user1Identity.NodeId
            $user1Roles = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Role' -and $_.ParentNodeId -eq $user1NodeId })
            $contributorRole = $user1Roles | Where-Object { $_.Label -match 'Contributor' }
            $contributorScopes = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Scope' -and $_.ParentNodeId -eq $contributorRole.NodeId })
            ($contributorScopes.Label -join ',') | Should -Not -Match 'via'
        }

        It 'Resolves subscription scope to friendly name' {
            $scopes = @($script:effectiveResult | Where-Object { $_.NodeType -eq 'Scope' })
            $subScopes = @($scopes | Where-Object { $_.Label -match 'subscription' })
            $subScopes | Should -Not -BeNullOrEmpty
            ($subScopes.Label -join ',') | Should -Match 'Visual Studio Enterprise'
        }

        It 'Has no duplicate NodeIds' {
            $ids = $script:effectiveResult | Select-Object -ExpandProperty NodeId
            ($ids | Select-Object -Unique).Count | Should -Be $ids.Count
        }

        It 'All non-root nodes have non-empty ParentNodeId' {
            $nonRoot = @($script:effectiveResult | Where-Object { $_.NodeType -ne 'Tenant' })
            foreach ($node in $nonRoot) {
                $node.ParentNodeId | Should -Not -BeNullOrEmpty
            }
        }

        It 'All nodes have non-empty Label' {
            foreach ($node in $script:effectiveResult) {
                $node.Label | Should -Not -BeNullOrEmpty
            }
        }

        It 'All non-root nodes have Relationship = HAS_ACCESS' {
            $nonRoot = @($script:effectiveResult | Where-Object { $_.NodeType -ne 'Tenant' })
            foreach ($node in $nonRoot) {
                $node.Relationship | Should -Be 'HAS_ACCESS'
            }
        }
    }

    Context 'Direct mode — raw role assignments from ARM resources' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"

            # Seed subscription for name resolution
            Save-CIEMAzureArmResource -Id '/subscriptions/sub1' `
                -Type 'microsoft.resources/subscriptions' -Name 'My Sub' `
                -SubscriptionId 'sub1' -TenantId 'tenant1'

            # Seed role definition for role name resolution
            $roleDefProps = @{ roleName = 'Contributor'; permissions = @(@{ actions = @('*') }) } | ConvertTo-Json -Compress
            Save-CIEMAzureArmResource -Id '/providers/Microsoft.Authorization/roleDefinitions/roledef-contrib' `
                -Type 'microsoft.authorization/roledefinitions' -Name 'Contributor' `
                -TenantId 'tenant1' -Properties $roleDefProps

            # Seed Entra resource for principal display name
            Save-CIEMAzureEntraResource -Id 'sp1-id' -Type 'servicePrincipal' `
                -DisplayName 'GitHub Actions SP'

            # Seed raw role assignment ARM resource
            $raProps = @{
                principalId       = 'sp1-id'
                principalType     = 'ServicePrincipal'
                roleDefinitionId  = '/providers/Microsoft.Authorization/roleDefinitions/roledef-contrib'
                scope             = '/subscriptions/sub1/resourceGroups/rg-deploy'
            } | ConvertTo-Json -Compress
            Save-CIEMAzureArmResource -Id '/subscriptions/sub1/providers/Microsoft.Authorization/roleAssignments/ra-1' `
                -Type 'microsoft.authorization/roleassignments' -Name 'ra-1' `
                -SubscriptionId 'sub1' -TenantId 'tenant1' -Properties $raProps

            $script:directResult = @(Get-CIEMAzureIdentityHierarchy -Mode Direct)
        }

        It 'Returns PSCustomObject array' {
            $script:directResult | Should -Not -BeNullOrEmpty
        }

        It 'Contains a ServicePrincipal identity type node' {
            $types = @($script:directResult | Where-Object { $_.NodeType -eq 'IdentityType' })
            ($types.Label -join ',') | Should -Match 'ServicePrincipal'
        }

        It 'Contains the GitHub Actions SP identity node' {
            $identities = @($script:directResult | Where-Object { $_.NodeType -eq 'Identity' })
            $identities.Label | Should -Contain 'GitHub Actions SP'
        }

        It 'Contains a Contributor role node' {
            $roles = @($script:directResult | Where-Object { $_.NodeType -eq 'Role' })
            ($roles.Label -join ',') | Should -Match 'Contributor'
        }

        It 'Contains a scope node for rg-deploy' {
            $scopes = @($script:directResult | Where-Object { $_.NodeType -eq 'Scope' })
            ($scopes.Label -join ',') | Should -Match 'rg-deploy'
        }

        It 'Has correct 5-level depth structure' {
            $maxDepth = ($script:directResult | Measure-Object -Property Depth -Maximum).Maximum
            $maxDepth | Should -Be 4
        }
    }

    Context '-SubscriptionId filter' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"

            # Seed two subscriptions
            Save-CIEMAzureArmResource -Id '/subscriptions/subA' `
                -Type 'microsoft.resources/subscriptions' -Name 'Sub A' `
                -SubscriptionId 'subA' -TenantId 'tenant1'
            Save-CIEMAzureArmResource -Id '/subscriptions/subB' `
                -Type 'microsoft.resources/subscriptions' -Name 'Sub B' `
                -SubscriptionId 'subB' -TenantId 'tenant1'

            # Assignment in subA
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-a' -PrincipalType 'User' `
                -PrincipalDisplayName 'User A' `
                -OriginalPrincipalId 'user-a' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'roledef-1' -RoleName 'Reader' `
                -Scope '/subscriptions/subA/resourceGroups/rg1' `
                -ComputedAt '2026-03-16T00:00:00Z'

            # Assignment in subB
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-b' -PrincipalType 'User' `
                -PrincipalDisplayName 'User B' `
                -OriginalPrincipalId 'user-b' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'roledef-2' -RoleName 'Owner' `
                -Scope '/subscriptions/subB' `
                -ComputedAt '2026-03-16T00:00:00Z'
        }

        It 'Returns only identities with scopes matching the specified subscription' {
            $result = @(Get-CIEMAzureIdentityHierarchy -Mode Effective -SubscriptionId 'subA')
            $identities = @($result | Where-Object { $_.NodeType -eq 'Identity' })
            $identities | Should -HaveCount 1
            $identities[0].Label | Should -Be 'User A'
        }

        It 'Excludes identities from other subscriptions' {
            $result = @(Get-CIEMAzureIdentityHierarchy -Mode Effective -SubscriptionId 'subA')
            $scopes = @($result | Where-Object { $_.NodeType -eq 'Scope' })
            ($scopes.Label -join ',') | Should -Not -Match 'Sub B'
        }
    }
}
