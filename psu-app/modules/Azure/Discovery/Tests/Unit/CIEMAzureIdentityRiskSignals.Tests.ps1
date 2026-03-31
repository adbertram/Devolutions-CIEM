BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSetup.ps1')
    Initialize-DiscoveryTestDatabase
}

Describe 'Get-CIEMAzureIdentityRiskSignals' {

    Context 'Command structure' {

        It 'Is available as a public command' {
            Get-Command Get-CIEMAzureIdentityRiskSignals -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory -PrincipalId parameter' {
            $param = (Get-Command Get-CIEMAzureIdentityRiskSignals).Parameters['PrincipalId']
            $param | Should -Not -BeNullOrEmpty
            $mandatory = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatory | Should -Not -BeNullOrEmpty
        }
    }

    Context 'User with direct and inherited roles' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"

            # User with 2 direct roles + 1 inherited via group
            Save-CIEMAzureEntraResource -Id 'user-mixed' -Type 'user' -DisplayName 'Mixed Roles User' -Properties (@{
                accountEnabled = $true
                signInActivity = @{ lastSignInDateTime = (Get-Date).AddDays(-5).ToString('o') }
            } | ConvertTo-Json -Compress)

            # Seed a group for the inherited role lookup
            Save-CIEMAzureEntraResource -Id 'group-admins' -Type 'group' -DisplayName 'Cloud Admins'

            # Direct: Reader
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-mixed' -PrincipalType 'User' -PrincipalDisplayName 'Mixed Roles User' `
                -OriginalPrincipalId 'user-mixed' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-reader' -RoleName 'Reader' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            # Direct: Contributor on RG
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-mixed' -PrincipalType 'User' -PrincipalDisplayName 'Mixed Roles User' `
                -OriginalPrincipalId 'user-mixed' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-contributor' -RoleName 'Contributor' `
                -Scope '/subscriptions/sub-1/resourceGroups/rg-web' -ComputedAt (Get-Date).ToString('o')

            # Inherited via group: Owner on subscription
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-mixed' -PrincipalType 'User' -PrincipalDisplayName 'Mixed Roles User' `
                -OriginalPrincipalId 'group-admins' -OriginalPrincipalType 'Group' `
                -RoleDefinitionId 'role-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            $script:result = Get-CIEMAzureIdentityRiskSignals -PrincipalId 'user-mixed'
        }

        It 'Returns object with expected properties' {
            $script:result.PSObject.Properties.Name | Should -Contain 'Identity'
            $script:result.PSObject.Properties.Name | Should -Contain 'RoleAssignments'
            $script:result.PSObject.Properties.Name | Should -Contain 'RiskSignals'
            $script:result.PSObject.Properties.Name | Should -Contain 'InheritedRoles'
        }

        It 'RoleAssignments contains all 3 effective assignments' {
            @($script:result.RoleAssignments) | Should -HaveCount 3
        }

        It 'InheritedRoles identifies the group-inherited assignment' {
            @($script:result.InheritedRoles) | Should -HaveCount 1
            $script:result.InheritedRoles[0].RoleName | Should -Be 'Owner'
            $script:result.InheritedRoles[0].InheritedFrom | Should -Be 'Cloud Admins'
        }

        It 'RiskSignals includes group-inherited-privileged-role signal' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'group-inherited-privileged-role' }
            $signal | Should -Not -BeNullOrEmpty
            $signal.Severity | Should -Be 'High'
        }
    }

    Context 'Managed identity with hosting resource and public IP' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"

            # Managed identity SP
            Save-CIEMAzureEntraResource -Id 'mi-vm-1' -Type 'servicePrincipal' -DisplayName 'vm-prod MI' -Properties (@{
                accountEnabled = $true
                servicePrincipalType = 'ManagedIdentity'
            } | ConvertTo-Json -Compress)

            # Owner on subscription
            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'mi-vm-1' -PrincipalType 'ServicePrincipal' -PrincipalDisplayName 'vm-prod MI' `
                -OriginalPrincipalId 'mi-vm-1' -OriginalPrincipalType 'ServicePrincipal' `
                -RoleDefinitionId 'role-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            # Hosting VM with managed identity
            Save-CIEMAzureArmResource `
                -Id '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-prod' `
                -Type 'microsoft.compute/virtualmachines' -Name 'vm-prod' `
                -ResourceGroup 'rg-prod' -SubscriptionId 'sub-1' `
                -Identity (@{ principalId = 'mi-vm-1'; type = 'SystemAssigned' } | ConvertTo-Json -Compress) `
                -CollectedAt (Get-Date).ToString('o')

            # Public IP in same resource group
            Save-CIEMAzureArmResource `
                -Id '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Network/publicIPAddresses/pip-vm-prod' `
                -Type 'microsoft.network/publicipaddresses' -Name 'pip-vm-prod' `
                -ResourceGroup 'rg-prod' -SubscriptionId 'sub-1' `
                -Properties (@{ ipAddress = '52.1.2.3' } | ConvertTo-Json -Compress) `
                -CollectedAt (Get-Date).ToString('o')

            $script:result = Get-CIEMAzureIdentityRiskSignals -PrincipalId 'mi-vm-1'
        }

        It 'Returns HostingResource with VM details' {
            $script:result.HostingResource | Should -Not -BeNullOrEmpty
            $script:result.HostingResource.Name | Should -Be 'vm-prod'
            $script:result.HostingResource.Type | Should -Be 'microsoft.compute/virtualmachines'
        }

        It 'HostingResource reports HasPublicIP as true' {
            $script:result.HostingResource.HasPublicIP | Should -BeTrue
        }

        It 'RiskSignals includes managed-identity-public-exposure' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'managed-identity-public-exposure' }
            $signal | Should -Not -BeNullOrEmpty
            $signal.Severity | Should -Be 'Critical'
        }
    }

    Context 'Dormant privileged permissions' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"

            $signIn120DaysAgo = (Get-Date).AddDays(-120).ToString('o')
            Save-CIEMAzureEntraResource -Id 'user-dormant' -Type 'user' -DisplayName 'Dormant Admin' -Properties (@{
                accountEnabled = $true
                signInActivity = @{ lastSignInDateTime = $signIn120DaysAgo }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-dormant' -PrincipalType 'User' -PrincipalDisplayName 'Dormant Admin' `
                -OriginalPrincipalId 'user-dormant' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            $script:result = Get-CIEMAzureIdentityRiskSignals -PrincipalId 'user-dormant'
        }

        It 'RiskSignals includes dormant-privileged-permissions' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal | Should -Not -BeNullOrEmpty
            $signal.Severity | Should -Be 'Critical'
        }

        It 'Dormant signal includes days_since_signin value' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal.DaysSinceSignIn | Should -BeGreaterOrEqual 120
        }
    }

    Context 'Privileged identity with no sign-in data' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"

            # User with no signInActivity at all
            Save-CIEMAzureEntraResource -Id 'user-no-signin' -Type 'user' -DisplayName 'No SignIn User' -Properties (@{
                accountEnabled = $true
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-no-signin' -PrincipalType 'User' -PrincipalDisplayName 'No SignIn User' `
                -OriginalPrincipalId 'user-no-signin' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            $script:result = Get-CIEMAzureIdentityRiskSignals -PrincipalId 'user-no-signin'
        }

        It 'RiskSignals includes dormant-privileged-permissions' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal | Should -Not -BeNullOrEmpty
            $signal.Severity | Should -Be 'Critical'
        }

        It 'Description indicates no recorded sign-in activity' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal.Description | Should -BeLike '*no recorded sign-in activity*'
        }

        It 'DaysSinceSignIn is null when no sign-in data exists' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal.DaysSinceSignIn | Should -BeNullOrEmpty
        }
    }

    Context 'SP with only non-interactive sign-in is NOT dormant' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"

            # SP with no interactive sign-in but recent non-interactive (2 days ago)
            Save-CIEMAzureEntraResource -Id 'sp-noninteractive' -Type 'servicePrincipal' -DisplayName 'Active SP' -Properties (@{
                accountEnabled = $true
                servicePrincipalType = 'Application'
                signInActivity = @{
                    lastNonInteractiveSignInDateTime = (Get-Date).AddDays(-2).ToString('o')
                }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'sp-noninteractive' -PrincipalType 'ServicePrincipal' -PrincipalDisplayName 'Active SP' `
                -OriginalPrincipalId 'sp-noninteractive' -OriginalPrincipalType 'ServicePrincipal' `
                -RoleDefinitionId 'role-contributor' -RoleName 'Contributor' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            $script:result = Get-CIEMAzureIdentityRiskSignals -PrincipalId 'sp-noninteractive'
        }

        It 'Does NOT trigger dormant-privileged-permissions signal' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal | Should -BeNullOrEmpty
        }

        It 'Identity output includes LastSignIn from non-interactive data' {
            $script:result.Identity.LastSignIn | Should -Not -BeNullOrEmpty
        }

        It 'Identity output includes LastInteractiveSignIn and LastNonInteractiveSignIn' {
            $script:result.Identity.PSObject.Properties.Name | Should -Contain 'LastInteractiveSignIn'
            $script:result.Identity.PSObject.Properties.Name | Should -Contain 'LastNonInteractiveSignIn'
            $script:result.Identity.LastInteractiveSignIn | Should -BeNullOrEmpty
            $script:result.Identity.LastNonInteractiveSignIn | Should -Not -BeNullOrEmpty
        }
    }

    Context 'SP with old interactive but recent non-interactive is NOT dormant' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"

            # SP: interactive 120 days ago, non-interactive 5 days ago
            Save-CIEMAzureEntraResource -Id 'sp-mixed-signin' -Type 'servicePrincipal' -DisplayName 'Mixed SignIn SP' -Properties (@{
                accountEnabled = $true
                servicePrincipalType = 'Application'
                signInActivity = @{
                    lastSignInDateTime = (Get-Date).AddDays(-120).ToString('o')
                    lastNonInteractiveSignInDateTime = (Get-Date).AddDays(-5).ToString('o')
                }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'sp-mixed-signin' -PrincipalType 'ServicePrincipal' -PrincipalDisplayName 'Mixed SignIn SP' `
                -OriginalPrincipalId 'sp-mixed-signin' -OriginalPrincipalType 'ServicePrincipal' `
                -RoleDefinitionId 'role-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            $script:result = Get-CIEMAzureIdentityRiskSignals -PrincipalId 'sp-mixed-signin'
        }

        It 'Does NOT trigger dormant-privileged-permissions signal' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal | Should -BeNullOrEmpty
        }

        It 'LastSignIn uses the more recent non-interactive date' {
            $lastSignIn = [datetime]$script:result.Identity.LastSignIn
            $daysSince = [math]::Floor(((Get-Date) - $lastSignIn).TotalDays)
            $daysSince | Should -BeLessOrEqual 10
        }

        It 'Both individual timestamps are populated' {
            $script:result.Identity.LastInteractiveSignIn | Should -Not -BeNullOrEmpty
            $script:result.Identity.LastNonInteractiveSignIn | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Disabled account with active assignments' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"

            Save-CIEMAzureEntraResource -Id 'user-disabled' -Type 'user' -DisplayName 'Disabled User' -Properties (@{
                accountEnabled = $false
                signInActivity = @{ lastSignInDateTime = (Get-Date).AddDays(-10).ToString('o') }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-disabled' -PrincipalType 'User' -PrincipalDisplayName 'Disabled User' `
                -OriginalPrincipalId 'user-disabled' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-contributor' -RoleName 'Contributor' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            $script:result = Get-CIEMAzureIdentityRiskSignals -PrincipalId 'user-disabled'
        }

        It 'RiskSignals includes disabled-with-permissions' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'disabled-with-permissions' }
            $signal | Should -Not -BeNullOrEmpty
            $signal.Severity | Should -Be 'High'
        }
    }

    Context 'Clean identity with no risk signals' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"

            Save-CIEMAzureEntraResource -Id 'user-clean' -Type 'user' -DisplayName 'Clean User' -Properties (@{
                accountEnabled = $true
                signInActivity = @{ lastSignInDateTime = (Get-Date).AddDays(-1).ToString('o') }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-clean' -PrincipalType 'User' -PrincipalDisplayName 'Clean User' `
                -OriginalPrincipalId 'user-clean' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-reader' -RoleName 'Reader' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            $script:result = Get-CIEMAzureIdentityRiskSignals -PrincipalId 'user-clean'
        }

        It 'Returns empty RiskSignals array' {
            @($script:result.RiskSignals) | Should -HaveCount 0
        }

        It 'RoleAssignments still populated' {
            @($script:result.RoleAssignments) | Should -HaveCount 1
            $script:result.RoleAssignments[0].RoleName | Should -Be 'Reader'
        }

        It 'HostingResource is null for non-managed-identity' {
            $script:result.HostingResource | Should -BeNullOrEmpty
        }
    }

    Context 'Identity not found' {

        It 'Throws when PrincipalId does not exist in entra resources' {
            { Get-CIEMAzureIdentityRiskSignals -PrincipalId 'nonexistent-id' } | Should -Throw
        }
    }
}
