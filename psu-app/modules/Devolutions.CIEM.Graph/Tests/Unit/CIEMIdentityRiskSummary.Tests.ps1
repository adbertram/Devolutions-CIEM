BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $graphSchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $graphSchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Get-CIEMIdentityRiskSummary' {

    Context 'Command structure' {

        It 'Is available as a public command' {
            Get-Command Get-CIEMIdentityRiskSummary -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has -PrincipalType parameter with ValidateSet' {
            $param = (Get-Command Get-CIEMIdentityRiskSummary).Parameters['PrincipalType']
            $param | Should -Not -BeNullOrEmpty
            $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'User'
            $validateSet.ValidValues | Should -Contain 'ServicePrincipal'
            $validateSet.ValidValues | Should -Contain 'ManagedIdentity'
            $validateSet.ValidValues | Should -Contain 'Group'
        }

        It 'Has -RiskLevel parameter with ValidateSet' {
            $param = (Get-Command Get-CIEMIdentityRiskSummary).Parameters['RiskLevel']
            $param | Should -Not -BeNullOrEmpty
            $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'Critical'
            $validateSet.ValidValues | Should -Contain 'High'
            $validateSet.ValidValues | Should -Contain 'Medium'
            $validateSet.ValidValues | Should -Contain 'Low'
        }

        It 'Has -SubscriptionId parameter' {
            $param = (Get-Command Get-CIEMIdentityRiskSummary).Parameters['SubscriptionId']
            $param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'No data' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
            $script:result = @(Get-CIEMIdentityRiskSummary)
        }

        It 'Returns empty array when no identity nodes exist' {
            $script:result | Should -HaveCount 0
        }
    }

    Context 'Basic summary -- 2 users, 1 SP, 1 managed identity' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            $now = Get-Date
            $collectedAt = $now.ToString('o')

            # User 1: Owner on subscription, last sign-in 120 days ago (Critical -- privileged + dormant)
            $signIn120DaysAgo = $now.AddDays(-120).ToString('o')
            Save-CIEMGraphNode -Id 'user-1' -Kind 'EntraUser' -DisplayName 'Alice Admin' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 120
                    lastSignIn               = $signIn120DaysAgo
                    lastInteractiveSignIn    = $signIn120DaysAgo
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            # Target node for the role edge (subscription scope)
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' `
                -CollectedAt $collectedAt

            Save-CIEMGraphEdge -SourceId 'user-1' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name     = 'Owner'
                    privileged    = $true
                    scope         = '/subscriptions/sub-1'
                    definition_id = 'role-owner'
                } | ConvertTo-Json -Compress)

            # User 2: Reader only, signed in yesterday (Low -- read-only)
            $signInYesterday = $now.AddDays(-1).ToString('o')
            Save-CIEMGraphNode -Id 'user-2' -Kind 'EntraUser' -DisplayName 'Bob Reader' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 1
                    lastSignIn               = $signInYesterday
                    lastInteractiveSignIn    = $signInYesterday
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'user-2' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name     = 'Reader'
                    privileged    = $false
                    scope         = '/subscriptions/sub-1'
                    definition_id = 'role-reader'
                } | ConvertTo-Json -Compress)

            # SP: Contributor on subscription, non-interactive sign-in 2 days ago (High -- privileged at sub scope)
            $spNonInteractive = $now.AddDays(-2).ToString('o')
            Save-CIEMGraphNode -Id 'sp-1' -Kind 'EntraServicePrincipal' -DisplayName 'Deploy SP' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 2
                    lastSignIn               = $spNonInteractive
                    lastInteractiveSignIn    = $null
                    lastNonInteractiveSignIn = $spNonInteractive
                    servicePrincipalType     = 'Application'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'sp-1' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name     = 'Contributor'
                    privileged    = $true
                    scope         = '/subscriptions/sub-1'
                    definition_id = 'role-contributor'
                } | ConvertTo-Json -Compress)

            # Managed identity: Owner on subscription, no sign-in data (Critical)
            Save-CIEMGraphNode -Id 'mi-1' -Kind 'EntraManagedIdentity' -DisplayName 'VM Managed Identity' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = $null
                    lastSignIn               = $null
                    lastInteractiveSignIn    = $null
                    lastNonInteractiveSignIn = $null
                    servicePrincipalType     = 'ManagedIdentity'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'mi-1' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name     = 'Owner'
                    privileged    = $true
                    scope         = '/subscriptions/sub-1'
                    definition_id = 'role-owner'
                } | ConvertTo-Json -Compress)

            $script:result = @(Get-CIEMIdentityRiskSummary)
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

        It 'EntitlementCount matches seeded role edges per identity' {
            ($script:result | Where-Object { $_.Id -eq 'user-1' }).EntitlementCount | Should -Be 1
            ($script:result | Where-Object { $_.Id -eq 'user-2' }).EntitlementCount | Should -Be 1
            ($script:result | Where-Object { $_.Id -eq 'sp-1' }).EntitlementCount | Should -Be 1
            ($script:result | Where-Object { $_.Id -eq 'mi-1' }).EntitlementCount | Should -Be 1
        }

        It 'PrivilegedCount correctly counts privileged role edges' {
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

        # Data seeded in previous context is still present
        BeforeAll {
            $script:usersOnly = @(Get-CIEMIdentityRiskSummary -PrincipalType User)
            $script:spsOnly = @(Get-CIEMIdentityRiskSummary -PrincipalType ServicePrincipal)
            $script:misOnly = @(Get-CIEMIdentityRiskSummary -PrincipalType ManagedIdentity)
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
            $criticals = @(Get-CIEMIdentityRiskSummary -RiskLevel Critical)
            $criticals.Count | Should -BeGreaterOrEqual 1
            $criticals | ForEach-Object { $_.RiskLevel | Should -Be 'Critical' }
        }

        It 'Returns only Low identities when -RiskLevel Low' {
            $lows = @(Get-CIEMIdentityRiskSummary -RiskLevel Low)
            $lows.Count | Should -BeGreaterOrEqual 1
            $lows | ForEach-Object { $_.RiskLevel | Should -Be 'Low' }
        }
    }

    Context 'Risk computation edge cases' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            $collectedAt = (Get-Date).ToString('o')

            # Target nodes for edges
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -CollectedAt $collectedAt

            1..6 | ForEach-Object {
                Save-CIEMGraphNode -Id "/subscriptions/sub-1/resourceGroups/rg-$_" -Kind 'AzureResourceGroup' `
                    -DisplayName "rg-$_" -CollectedAt $collectedAt
            }

            # Disabled user with privileged role = Critical
            Save-CIEMGraphNode -Id 'user-disabled' -Kind 'EntraUser' -DisplayName 'Disabled Admin' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $false
                    daysSinceSignIn          = 10
                    lastSignIn               = (Get-Date).AddDays(-10).ToString('o')
                    lastInteractiveSignIn    = (Get-Date).AddDays(-10).ToString('o')
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'user-disabled' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name     = 'Owner'
                    privileged    = $true
                    scope         = '/subscriptions/sub-1'
                    definition_id = 'role-owner'
                } | ConvertTo-Json -Compress)

            # User with 6 non-privileged roles = Medium (>5 entitlements)
            Save-CIEMGraphNode -Id 'user-many-roles' -Kind 'EntraUser' -DisplayName 'Many Roles User' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 1
                    lastSignIn               = (Get-Date).AddDays(-1).ToString('o')
                    lastInteractiveSignIn    = (Get-Date).AddDays(-1).ToString('o')
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            1..6 | ForEach-Object {
                Save-CIEMGraphEdge -SourceId 'user-many-roles' `
                    -TargetId "/subscriptions/sub-1/resourceGroups/rg-$_" `
                    -Kind 'HasRole' `
                    -CollectedAt $collectedAt `
                    -Properties (@{
                        role_name     = "Custom Role $_"
                        privileged    = $false
                        scope         = "/subscriptions/sub-1/resourceGroups/rg-$_"
                        definition_id = "role-custom-$_"
                    } | ConvertTo-Json -Compress)
            }

            # User with group-inherited Owner on subscription = High (InheritedRole edge)
            Save-CIEMGraphNode -Id 'user-inherited' -Kind 'EntraUser' -DisplayName 'Inherited User' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 5
                    lastSignIn               = (Get-Date).AddDays(-5).ToString('o')
                    lastInteractiveSignIn    = (Get-Date).AddDays(-5).ToString('o')
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'user-inherited' -TargetId '/subscriptions/sub-1' -Kind 'InheritedRole' `
                -Computed 1 -CollectedAt $collectedAt `
                -Properties (@{
                    role_name     = 'Owner'
                    privileged    = $true
                    scope         = '/subscriptions/sub-1'
                    definition_id = 'role-owner'
                } | ConvertTo-Json -Compress)

            $script:edgeCases = @(Get-CIEMIdentityRiskSummary)
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

    Context '-SubscriptionId filter' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            $collectedAt = (Get-Date).ToString('o')

            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -CollectedAt $collectedAt
            Save-CIEMGraphNode -Id '/subscriptions/sub-2' -Kind 'AzureSubscription' -DisplayName 'Sub 2' -CollectedAt $collectedAt

            Save-CIEMGraphNode -Id 'user-sub-filter' -Kind 'EntraUser' -DisplayName 'Sub Filter User' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 5
                    lastSignIn               = (Get-Date).AddDays(-5).ToString('o')
                    lastInteractiveSignIn    = (Get-Date).AddDays(-5).ToString('o')
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            # Role on sub-1
            Save-CIEMGraphEdge -SourceId 'user-sub-filter' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name     = 'Reader'
                    privileged    = $false
                    scope         = '/subscriptions/sub-1'
                    definition_id = 'role-reader'
                } | ConvertTo-Json -Compress)

            # Role on sub-2
            Save-CIEMGraphEdge -SourceId 'user-sub-filter' -TargetId '/subscriptions/sub-2' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name     = 'Contributor'
                    privileged    = $true
                    scope         = '/subscriptions/sub-2'
                    definition_id = 'role-contrib'
                } | ConvertTo-Json -Compress)
        }

        It 'Returns identity with assignments scoped to the specified subscription' {
            $filtered = @(Get-CIEMIdentityRiskSummary -SubscriptionId 'sub-1')
            $filtered | Should -HaveCount 1
            $filtered[0].EntitlementCount | Should -Be 1
        }

        It 'Returns identity with zero entitlements when subscription has no matching edges' {
            $filtered = @(Get-CIEMIdentityRiskSummary -SubscriptionId 'sub-nonexistent')
            $filtered | Should -HaveCount 1
            $filtered[0].EntitlementCount | Should -Be 0
        }
    }

    Context 'DaysSinceSignIn from node properties' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            $collectedAt = '2026-03-01T12:00:00'

            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' `
                -CollectedAt $collectedAt

            # Seed with explicit daysSinceSignIn = 90 (pre-computed during graph build)
            Save-CIEMGraphNode -Id 'user-ref-date' -Kind 'EntraUser' -DisplayName 'RefDate User' `
                -CollectedAt $collectedAt -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 90
                    lastSignIn               = '2025-12-01T12:00:00'
                    lastInteractiveSignIn    = '2025-12-01T12:00:00'
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'user-ref-date' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name     = 'Reader'
                    privileged    = $false
                    scope         = '/subscriptions/sub-1'
                    definition_id = 'role-reader'
                } | ConvertTo-Json -Compress)

            $script:refDateResult = @(Get-CIEMIdentityRiskSummary)
        }

        It 'Reads DaysSinceSignIn directly from node properties JSON' {
            $user = $script:refDateResult | Where-Object { $_.Id -eq 'user-ref-date' }
            $user.DaysSinceSignIn | Should -Be 90
        }
    }

    Context 'Identity node with no role edges' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            $collectedAt = (Get-Date).ToString('o')

            Save-CIEMGraphNode -Id 'user-no-roles' -Kind 'EntraUser' -DisplayName 'No Roles User' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 5
                    lastSignIn               = (Get-Date).AddDays(-5).ToString('o')
                    lastInteractiveSignIn    = (Get-Date).AddDays(-5).ToString('o')
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            $script:noRolesResult = @(Get-CIEMIdentityRiskSummary)
        }

        It 'Returns identity with zero entitlements and Low risk' {
            $script:noRolesResult | Should -HaveCount 1
            $script:noRolesResult[0].EntitlementCount | Should -Be 0
            $script:noRolesResult[0].PrivilegedCount | Should -Be 0
            $script:noRolesResult[0].InheritedCount | Should -Be 0
            $script:noRolesResult[0].RiskLevel | Should -Be 'Low'
        }
    }

    Context 'Entitlement threshold boundary at exactly 5 assignments' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            $collectedAt = (Get-Date).ToString('o')

            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -CollectedAt $collectedAt

            1..5 | ForEach-Object {
                Save-CIEMGraphNode -Id "/subscriptions/sub-1/resourceGroups/rg-boundary-$_" -Kind 'AzureResourceGroup' `
                    -DisplayName "rg-boundary-$_" -CollectedAt $collectedAt
            }

            # Active user with exactly 5 non-privileged role assignments
            Save-CIEMGraphNode -Id 'user-boundary-5' -Kind 'EntraUser' -DisplayName 'Boundary 5 User' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 1
                    lastSignIn               = (Get-Date).AddDays(-1).ToString('o')
                    lastInteractiveSignIn    = (Get-Date).AddDays(-1).ToString('o')
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            1..5 | ForEach-Object {
                Save-CIEMGraphEdge -SourceId 'user-boundary-5' `
                    -TargetId "/subscriptions/sub-1/resourceGroups/rg-boundary-$_" `
                    -Kind 'HasRole' `
                    -CollectedAt $collectedAt `
                    -Properties (@{
                        role_name     = "Custom Role $_"
                        privileged    = $false
                        scope         = "/subscriptions/sub-1/resourceGroups/rg-boundary-$_"
                        definition_id = "role-custom-$_"
                    } | ConvertTo-Json -Compress)
            }

            $script:boundary5Result = @(Get-CIEMIdentityRiskSummary)
        }

        It 'Identity with exactly 5 non-privileged assignments gets Low risk (threshold uses -gt not -ge)' {
            $user = $script:boundary5Result | Where-Object { $_.Id -eq 'user-boundary-5' }
            $user.EntitlementCount | Should -Be 5
            $user.RiskLevel | Should -Be 'Low'
        }
    }

    Context 'Entitlement threshold boundary at 6 assignments' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            $collectedAt = (Get-Date).ToString('o')

            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -CollectedAt $collectedAt

            1..6 | ForEach-Object {
                Save-CIEMGraphNode -Id "/subscriptions/sub-1/resourceGroups/rg-boundary-$_" -Kind 'AzureResourceGroup' `
                    -DisplayName "rg-boundary-$_" -CollectedAt $collectedAt
            }

            # Active user with 6 non-privileged role assignments (one past threshold)
            Save-CIEMGraphNode -Id 'user-boundary-6' -Kind 'EntraUser' -DisplayName 'Boundary 6 User' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled           = $true
                    daysSinceSignIn          = 1
                    lastSignIn               = (Get-Date).AddDays(-1).ToString('o')
                    lastInteractiveSignIn    = (Get-Date).AddDays(-1).ToString('o')
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            1..6 | ForEach-Object {
                Save-CIEMGraphEdge -SourceId 'user-boundary-6' `
                    -TargetId "/subscriptions/sub-1/resourceGroups/rg-boundary-$_" `
                    -Kind 'HasRole' `
                    -CollectedAt $collectedAt `
                    -Properties (@{
                        role_name     = "Custom Role $_"
                        privileged    = $false
                        scope         = "/subscriptions/sub-1/resourceGroups/rg-boundary-$_"
                        definition_id = "role-custom-$_"
                    } | ConvertTo-Json -Compress)
            }

            $script:boundary6Result = @(Get-CIEMIdentityRiskSummary)
        }

        It 'Identity with 6 non-privileged assignments gets Medium risk (one past threshold)' {
            $user = $script:boundary6Result | Where-Object { $_.Id -eq 'user-boundary-6' }
            $user.EntitlementCount | Should -Be 6
            $user.RiskLevel | Should -Be 'Medium'
        }
    }
}
