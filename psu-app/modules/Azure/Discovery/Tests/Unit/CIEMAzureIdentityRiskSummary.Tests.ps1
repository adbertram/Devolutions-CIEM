BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSetup.ps1')
    Initialize-DiscoveryTestDatabase
}

Describe 'Get-CIEMAzureIdentityRiskSummary' {

    Context 'Command structure' {

        It 'Is available as a public command' {
            Get-Command Get-CIEMAzureIdentityRiskSummary -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has -PrincipalType parameter with ValidateSet' {
            $param = (Get-Command Get-CIEMAzureIdentityRiskSummary).Parameters['PrincipalType']
            $param | Should -Not -BeNullOrEmpty
            $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'User'
            $validateSet.ValidValues | Should -Contain 'ServicePrincipal'
            $validateSet.ValidValues | Should -Contain 'ManagedIdentity'
            $validateSet.ValidValues | Should -Contain 'Group'
        }

        It 'Has -RiskLevel parameter with ValidateSet' {
            $param = (Get-Command Get-CIEMAzureIdentityRiskSummary).Parameters['RiskLevel']
            $param | Should -Not -BeNullOrEmpty
            $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'Critical'
            $validateSet.ValidValues | Should -Contain 'High'
            $validateSet.ValidValues | Should -Contain 'Medium'
            $validateSet.ValidValues | Should -Contain 'Low'
        }

        It 'Has -SubscriptionId parameter' {
            $param = (Get-Command Get-CIEMAzureIdentityRiskSummary).Parameters['SubscriptionId']
            $param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'No data' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
            $script:result = @(Get-CIEMAzureIdentityRiskSummary)
        }

        It 'Returns empty array when no entra resources exist' {
            $script:result | Should -HaveCount 0
        }
    }

    Context 'Basic summary — 2 users, 1 SP, 1 managed identity' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"

            # User 1: Owner on subscription, last sign-in 120 days ago (Critical — privileged + dormant)
            $signIn120DaysAgo = (Get-Date).AddDays(-120).ToString('o')
            Save-CIEMAzureEntraResource -Id 'user-1' -Type 'user' -DisplayName 'Alice Admin' -Properties (@{
                accountEnabled = $true
                signInActivity = @{ lastSignInDateTime = $signIn120DaysAgo }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-1' -PrincipalType 'User' -PrincipalDisplayName 'Alice Admin' `
                -OriginalPrincipalId 'user-1' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            # User 2: Reader only, signed in yesterday (Low — read-only)
            $signInYesterday = (Get-Date).AddDays(-1).ToString('o')
            Save-CIEMAzureEntraResource -Id 'user-2' -Type 'user' -DisplayName 'Bob Reader' -Properties (@{
                accountEnabled = $true
                signInActivity = @{ lastSignInDateTime = $signInYesterday }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-2' -PrincipalType 'User' -PrincipalDisplayName 'Bob Reader' `
                -OriginalPrincipalId 'user-2' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-reader' -RoleName 'Reader' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            # SP: Contributor on subscription, non-interactive sign-in 2 days ago (High — privileged at sub scope)
            Save-CIEMAzureEntraResource -Id 'sp-1' -Type 'servicePrincipal' -DisplayName 'Deploy SP' -Properties (@{
                accountEnabled = $true
                servicePrincipalType = 'Application'
                signInActivity = @{ lastNonInteractiveSignInDateTime = (Get-Date).AddDays(-2).ToString('o') }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'sp-1' -PrincipalType 'ServicePrincipal' -PrincipalDisplayName 'Deploy SP' `
                -OriginalPrincipalId 'sp-1' -OriginalPrincipalType 'ServicePrincipal' `
                -RoleDefinitionId 'role-contributor' -RoleName 'Contributor' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            # Managed identity: Owner on subscription, no sign-in data (Critical)
            Save-CIEMAzureEntraResource -Id 'mi-1' -Type 'servicePrincipal' -DisplayName 'VM Managed Identity' -Properties (@{
                accountEnabled = $true
                servicePrincipalType = 'ManagedIdentity'
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'mi-1' -PrincipalType 'ServicePrincipal' -PrincipalDisplayName 'VM Managed Identity' `
                -OriginalPrincipalId 'mi-1' -OriginalPrincipalType 'ServicePrincipal' `
                -RoleDefinitionId 'role-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            $script:result = @(Get-CIEMAzureIdentityRiskSummary)
        }

        It 'Returns 4 identity rows' {
            $script:result | Should -HaveCount 4
        }

        It 'Each row has expected properties including sign-in breakdown' {
            foreach ($row in $script:result) {
                $row.PSObject.Properties.Name | Should -Contain 'Id'
                $row.PSObject.Properties.Name | Should -Contain 'DisplayName'
                $row.PSObject.Properties.Name | Should -Contain 'PrincipalType'
                $row.PSObject.Properties.Name | Should -Contain 'AccountEnabled'
                $row.PSObject.Properties.Name | Should -Contain 'EntitlementCount'
                $row.PSObject.Properties.Name | Should -Contain 'PrivilegedCount'
                $row.PSObject.Properties.Name | Should -Contain 'InheritedCount'
                $row.PSObject.Properties.Name | Should -Contain 'LastSignIn'
                $row.PSObject.Properties.Name | Should -Contain 'DaysSinceSignIn'
                $row.PSObject.Properties.Name | Should -Contain 'RiskLevel'
                $row.PSObject.Properties.Name | Should -Contain 'LastInteractiveSignIn'
                $row.PSObject.Properties.Name | Should -Contain 'LastNonInteractiveSignIn'
            }
        }

        It 'EntitlementCount matches seeded role assignments per principal' {
            ($script:result | Where-Object { $_.Id -eq 'user-1' }).EntitlementCount | Should -Be 1
            ($script:result | Where-Object { $_.Id -eq 'user-2' }).EntitlementCount | Should -Be 1
            ($script:result | Where-Object { $_.Id -eq 'sp-1' }).EntitlementCount | Should -Be 1
            ($script:result | Where-Object { $_.Id -eq 'mi-1' }).EntitlementCount | Should -Be 1
        }

        It 'PrivilegedCount correctly counts Owner/Contributor/UAA roles' {
            ($script:result | Where-Object { $_.Id -eq 'user-1' }).PrivilegedCount | Should -Be 1
            ($script:result | Where-Object { $_.Id -eq 'user-2' }).PrivilegedCount | Should -Be 0
            ($script:result | Where-Object { $_.Id -eq 'sp-1' }).PrivilegedCount | Should -Be 1
            ($script:result | Where-Object { $_.Id -eq 'mi-1' }).PrivilegedCount | Should -Be 1
        }

        It 'User with Owner on subscription and no sign-in in 90d gets Critical risk' {
            ($script:result | Where-Object { $_.Id -eq 'user-1' }).RiskLevel | Should -Be 'Critical'
        }

        It 'User with Reader only gets Low risk' {
            ($script:result | Where-Object { $_.Id -eq 'user-2' }).RiskLevel | Should -Be 'Low'
        }

        It 'SP with Contributor on subscription and recent non-interactive sign-in gets High risk' {
            ($script:result | Where-Object { $_.Id -eq 'sp-1' }).RiskLevel | Should -Be 'High'
        }

        It 'SP LastSignIn uses non-interactive date when no interactive exists' {
            $sp = $script:result | Where-Object { $_.Id -eq 'sp-1' }
            $sp.LastSignIn | Should -Not -BeNullOrEmpty
            $sp.DaysSinceSignIn | Should -BeLessOrEqual 5
            $sp.LastInteractiveSignIn | Should -BeNullOrEmpty
            $sp.LastNonInteractiveSignIn | Should -Not -BeNullOrEmpty
        }

        It 'Managed identity with Owner and no sign-in data gets Critical risk' {
            ($script:result | Where-Object { $_.Id -eq 'mi-1' }).RiskLevel | Should -Be 'Critical'
        }

        It 'DaysSinceSignIn is null when no sign-in data exists' {
            ($script:result | Where-Object { $_.Id -eq 'mi-1' }).DaysSinceSignIn | Should -BeNullOrEmpty
        }

        It 'Reports correct PrincipalType for managed identity' {
            ($script:result | Where-Object { $_.Id -eq 'mi-1' }).PrincipalType | Should -Be 'ManagedIdentity'
        }

        It 'Reports correct PrincipalType for regular SP' {
            ($script:result | Where-Object { $_.Id -eq 'sp-1' }).PrincipalType | Should -Be 'ServicePrincipal'
        }
    }

    Context '-PrincipalType filter' {

        BeforeAll {
            # Data seeded in previous context is still present
            $script:usersOnly = @(Get-CIEMAzureIdentityRiskSummary -PrincipalType User)
            $script:spsOnly = @(Get-CIEMAzureIdentityRiskSummary -PrincipalType ServicePrincipal)
            $script:misOnly = @(Get-CIEMAzureIdentityRiskSummary -PrincipalType ManagedIdentity)
        }

        It 'Returns only User identities when -PrincipalType User' {
            $script:usersOnly | Should -HaveCount 2
            $script:usersOnly | ForEach-Object { $_.PrincipalType | Should -Be 'User' }
        }

        It 'Returns only ServicePrincipal (non-MI) when -PrincipalType ServicePrincipal' {
            $script:spsOnly | Should -HaveCount 1
            $script:spsOnly[0].DisplayName | Should -Be 'Deploy SP'
        }

        It 'Returns only ManagedIdentity when -PrincipalType ManagedIdentity' {
            $script:misOnly | Should -HaveCount 1
            $script:misOnly[0].DisplayName | Should -Be 'VM Managed Identity'
        }
    }

    Context '-RiskLevel filter' {

        It 'Returns only Critical identities when -RiskLevel Critical' {
            $criticals = @(Get-CIEMAzureIdentityRiskSummary -RiskLevel Critical)
            $criticals.Count | Should -BeGreaterOrEqual 1
            $criticals | ForEach-Object { $_.RiskLevel | Should -Be 'Critical' }
        }

        It 'Returns only Low identities when -RiskLevel Low' {
            $lows = @(Get-CIEMAzureIdentityRiskSummary -RiskLevel Low)
            $lows.Count | Should -BeGreaterOrEqual 1
            $lows | ForEach-Object { $_.RiskLevel | Should -Be 'Low' }
        }
    }

    Context 'Risk computation edge cases' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"

            # Disabled user with privileged role = Critical
            Save-CIEMAzureEntraResource -Id 'user-disabled' -Type 'user' -DisplayName 'Disabled Admin' -Properties (@{
                accountEnabled = $false
                signInActivity = @{ lastSignInDateTime = (Get-Date).AddDays(-10).ToString('o') }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-disabled' -PrincipalType 'User' -PrincipalDisplayName 'Disabled Admin' `
                -OriginalPrincipalId 'user-disabled' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            # User with 6 non-privileged roles = Medium
            Save-CIEMAzureEntraResource -Id 'user-many-roles' -Type 'user' -DisplayName 'Many Roles User' -Properties (@{
                accountEnabled = $true
                signInActivity = @{ lastSignInDateTime = (Get-Date).AddDays(-1).ToString('o') }
            } | ConvertTo-Json -Compress)

            1..6 | ForEach-Object {
                Save-CIEMAzureEffectiveRoleAssignment `
                    -PrincipalId 'user-many-roles' -PrincipalType 'User' -PrincipalDisplayName 'Many Roles User' `
                    -OriginalPrincipalId 'user-many-roles' -OriginalPrincipalType 'User' `
                    -RoleDefinitionId "role-custom-$_" -RoleName "Custom Role $_" `
                    -Scope "/subscriptions/sub-1/resourceGroups/rg-$_" -ComputedAt (Get-Date).ToString('o')
            }

            # User with group-inherited Owner on subscription = High
            Save-CIEMAzureEntraResource -Id 'user-inherited' -Type 'user' -DisplayName 'Inherited User' -Properties (@{
                accountEnabled = $true
                signInActivity = @{ lastSignInDateTime = (Get-Date).AddDays(-5).ToString('o') }
            } | ConvertTo-Json -Compress)

            Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-inherited' -PrincipalType 'User' -PrincipalDisplayName 'Inherited User' `
                -OriginalPrincipalId 'group-admins' -OriginalPrincipalType 'Group' `
                -RoleDefinitionId 'role-owner' -RoleName 'Owner' `
                -Scope '/subscriptions/sub-1' -ComputedAt (Get-Date).ToString('o')

            $script:edgeCases = @(Get-CIEMAzureIdentityRiskSummary)
        }

        It 'Disabled user with privileged roles gets Critical' {
            ($script:edgeCases | Where-Object { $_.Id -eq 'user-disabled' }).RiskLevel | Should -Be 'Critical'
        }

        It 'User with >5 assignments but no privileged roles gets Medium' {
            ($script:edgeCases | Where-Object { $_.Id -eq 'user-many-roles' }).RiskLevel | Should -Be 'Medium'
        }

        It 'User with group-inherited Owner gets High' {
            $inherited = $script:edgeCases | Where-Object { $_.Id -eq 'user-inherited' }
            $inherited.RiskLevel | Should -Be 'High'
            $inherited.InheritedCount | Should -Be 1
        }
    }
}
