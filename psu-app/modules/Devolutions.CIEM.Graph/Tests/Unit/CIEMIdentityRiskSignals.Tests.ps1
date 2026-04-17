BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Create isolated test DB with base + azure + discovery + graph schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Discovery' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    $graphSchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $graphSchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Get-CIEMIdentityRiskSignals' {

    Context 'Command structure' {

        It 'Is available as a public command' {
            Get-Command Get-CIEMIdentityRiskSignals -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory -PrincipalId parameter' {
            $param = (Get-Command Get-CIEMIdentityRiskSignals).Parameters['PrincipalId']
            $param | Should -Not -BeNullOrEmpty
            $mandatory = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatory | Should -Not -BeNullOrEmpty
        }
    }

    Context 'User with direct and inherited roles' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # User node with recent sign-in (5 days ago via pre-computed properties)
            Save-CIEMGraphNode -Id 'user-mixed' -Kind 'EntraUser' -DisplayName 'Mixed Roles User' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    daysSinceSignIn = 5
                    lastSignIn = (Get-Date).AddDays(-5).ToString('o')
                    lastInteractiveSignIn = (Get-Date).AddDays(-5).ToString('o')
                } | ConvertTo-Json -Compress)

            # Group node for inherited role lookup
            Save-CIEMGraphNode -Id 'group-admins' -Kind 'EntraGroup' -DisplayName 'Cloud Admins' -Provider 'azure'

            # Scope target nodes (subscriptions/RGs must exist as nodes for FK)
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub-1/resourceGroups/rg-web' -Kind 'AzureResourceGroup' -DisplayName 'rg-web' -Provider 'azure'

            # Direct: Reader (non-privileged)
            Save-CIEMGraphEdge -SourceId 'user-mixed' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Reader'; privileged = $false; scope = '/subscriptions/sub-1'; definition_id = 'role-reader' } | ConvertTo-Json -Compress)

            # Direct: Contributor on RG (non-privileged)
            Save-CIEMGraphEdge -SourceId 'user-mixed' -TargetId '/subscriptions/sub-1/resourceGroups/rg-web' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Contributor'; privileged = $false; scope = '/subscriptions/sub-1/resourceGroups/rg-web'; definition_id = 'role-contributor' } | ConvertTo-Json -Compress)

            # Inherited via group: Owner on subscription (privileged)
            Save-CIEMGraphEdge -SourceId 'user-mixed' -TargetId '/subscriptions/sub-1' -Kind 'InheritedRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-1'; definition_id = 'role-owner'; inherited_from = 'group-admins'; inherited_from_name = 'Cloud Admins' } | ConvertTo-Json -Compress)

            # MemberOf edge: user -> group (for InheritedFrom lookup)
            Save-CIEMGraphEdge -SourceId 'user-mixed' -TargetId 'group-admins' -Kind 'MemberOf' -Computed 0

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'user-mixed'
        }

        It 'Returns object with expected properties' {
            $script:result.PSObject.Properties.Name | Should -Contain 'Identities'
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

        It 'Identity output includes correct fields from node properties' {
            $script:result.Identity.Id | Should -Be 'user-mixed'
            $script:result.Identity.DisplayName | Should -Be 'Mixed Roles User'
            $script:result.Identity.Type | Should -Be 'EntraUser'
            $script:result.Identity.AccountEnabled | Should -BeTrue
        }
    }

    Context 'Managed identity with hosting resource and public IP' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # Managed identity SP node
            Save-CIEMGraphNode -Id 'mi-vm-1' -Kind 'EntraManagedIdentity' -DisplayName 'vm-prod MI' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    servicePrincipalType = 'ManagedIdentity'
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            # Owner on subscription (privileged)
            Save-CIEMGraphEdge -SourceId 'mi-vm-1' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-1'; definition_id = 'role-owner' } | ConvertTo-Json -Compress)

            # Hosting VM
            Save-CIEMGraphNode -Id '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-prod' `
                -Kind 'AzureVM' -DisplayName 'vm-prod' -Provider 'azure' -ResourceGroup 'rg-prod'

            # HasManagedIdentity edge: VM -> MI
            Save-CIEMGraphEdge -SourceId '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-prod' `
                -TargetId 'mi-vm-1' -Kind 'HasManagedIdentity' -Computed 1

            # NIC attached to the VM
            Save-CIEMGraphNode -Id '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Network/networkInterfaces/vm-prod-nic' `
                -Kind 'AzureNIC' -DisplayName 'vm-prod-nic' -Provider 'azure' -ResourceGroup 'rg-prod'

            # AttachedTo edge: NIC -> VM
            Save-CIEMGraphEdge -SourceId '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Network/networkInterfaces/vm-prod-nic' `
                -TargetId '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-prod' `
                -Kind 'AttachedTo' -Computed 1

            # Public IP
            Save-CIEMGraphNode -Id '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Network/publicIPAddresses/pip-vm-prod' `
                -Kind 'AzurePublicIP' -DisplayName 'pip-vm-prod' -Provider 'azure' -ResourceGroup 'rg-prod'

            # HasPublicIP edge: NIC -> PublicIP
            Save-CIEMGraphEdge -SourceId '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Network/networkInterfaces/vm-prod-nic' `
                -TargetId '/subscriptions/sub-1/resourceGroups/rg-prod/providers/Microsoft.Network/publicIPAddresses/pip-vm-prod' `
                -Kind 'HasPublicIP' -Computed 1

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'mi-vm-1'
        }

        It 'Returns HostingResource with VM details' {
            $script:result.HostingResource | Should -Not -BeNullOrEmpty
            $script:result.HostingResource.Name | Should -Be 'vm-prod'
            $script:result.HostingResource.Type | Should -Be 'AzureVM'
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
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # User with daysSinceSignIn = 120 (pre-computed in properties)
            Save-CIEMGraphNode -Id 'user-dormant' -Kind 'EntraUser' -DisplayName 'Dormant Admin' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    daysSinceSignIn = 120
                    lastSignIn = '2025-11-01T12:00:00Z'
                    lastInteractiveSignIn = '2025-11-01T12:00:00Z'
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            # Privileged role
            Save-CIEMGraphEdge -SourceId 'user-dormant' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-1'; definition_id = 'role-owner' } | ConvertTo-Json -Compress)

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'user-dormant'
        }

        It 'RiskSignals includes dormant-privileged-permissions' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal | Should -Not -BeNullOrEmpty
            $signal.Severity | Should -Be 'Critical'
        }

        It 'Dormant signal includes DaysSinceSignIn value' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal.DaysSinceSignIn | Should -Be 120
        }
    }

    Context 'Privileged identity with no sign-in data' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # User with no sign-in properties at all
            Save-CIEMGraphNode -Id 'user-no-signin' -Kind 'EntraUser' -DisplayName 'No SignIn User' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            # Privileged role
            Save-CIEMGraphEdge -SourceId 'user-no-signin' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-1'; definition_id = 'role-owner' } | ConvertTo-Json -Compress)

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'user-no-signin'
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
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # SP node with recent non-interactive sign-in (pre-computed: daysSinceSignIn = 2)
            Save-CIEMGraphNode -Id 'sp-noninteractive' -Kind 'EntraServicePrincipal' -DisplayName 'Active SP' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    servicePrincipalType = 'Application'
                    daysSinceSignIn = 2
                    lastSignIn = (Get-Date).AddDays(-2).ToString('o')
                    lastNonInteractiveSignIn = (Get-Date).AddDays(-2).ToString('o')
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            # Non-privileged role (Contributor is not in the privileged list)
            Save-CIEMGraphEdge -SourceId 'sp-noninteractive' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Contributor'; privileged = $false; scope = '/subscriptions/sub-1'; definition_id = 'role-contributor' } | ConvertTo-Json -Compress)

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'sp-noninteractive'
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
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # SP: interactive 120 days ago, non-interactive 5 days ago - daysSinceSignIn uses most recent = 5
            Save-CIEMGraphNode -Id 'sp-mixed-signin' -Kind 'EntraServicePrincipal' -DisplayName 'Mixed SignIn SP' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    servicePrincipalType = 'Application'
                    daysSinceSignIn = 5
                    lastSignIn = (Get-Date).AddDays(-5).ToString('o')
                    lastInteractiveSignIn = (Get-Date).AddDays(-120).ToString('o')
                    lastNonInteractiveSignIn = (Get-Date).AddDays(-5).ToString('o')
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            # Privileged role (Owner)
            Save-CIEMGraphEdge -SourceId 'sp-mixed-signin' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-1'; definition_id = 'role-owner' } | ConvertTo-Json -Compress)

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'sp-mixed-signin'
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
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'user-disabled' -Kind 'EntraUser' -DisplayName 'Disabled User' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $false
                    daysSinceSignIn = 10
                    lastSignIn = (Get-Date).AddDays(-10).ToString('o')
                    lastInteractiveSignIn = (Get-Date).AddDays(-10).ToString('o')
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId 'user-disabled' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Contributor'; privileged = $false; scope = '/subscriptions/sub-1'; definition_id = 'role-contributor' } | ConvertTo-Json -Compress)

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'user-disabled'
        }

        It 'RiskSignals includes disabled-with-permissions' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'disabled-with-permissions' }
            $signal | Should -Not -BeNullOrEmpty
            $signal.Severity | Should -Be 'High'
        }
    }

    Context 'Clean identity with no risk signals' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'user-clean' -Kind 'EntraUser' -DisplayName 'Clean User' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    daysSinceSignIn = 1
                    lastSignIn = (Get-Date).AddDays(-1).ToString('o')
                    lastInteractiveSignIn = (Get-Date).AddDays(-1).ToString('o')
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId 'user-clean' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Reader'; privileged = $false; scope = '/subscriptions/sub-1'; definition_id = 'role-reader' } | ConvertTo-Json -Compress)

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'user-clean'
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

    Context 'Managed identity without public IP exposure' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # Managed identity node
            Save-CIEMGraphNode -Id 'mi-nopip' -Kind 'EntraManagedIdentity' -DisplayName 'private-vm MI' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    servicePrincipalType = 'ManagedIdentity'
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            # Owner role
            Save-CIEMGraphEdge -SourceId 'mi-nopip' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-1'; definition_id = 'role-owner' } | ConvertTo-Json -Compress)

            # Hosting VM (no public IP)
            Save-CIEMGraphNode -Id '/subscriptions/sub-1/resourceGroups/rg-priv/providers/Microsoft.Compute/virtualMachines/vm-priv' `
                -Kind 'AzureVM' -DisplayName 'vm-priv' -Provider 'azure' -ResourceGroup 'rg-priv'

            Save-CIEMGraphEdge -SourceId '/subscriptions/sub-1/resourceGroups/rg-priv/providers/Microsoft.Compute/virtualMachines/vm-priv' `
                -TargetId 'mi-nopip' -Kind 'HasManagedIdentity' -Computed 1

            # NIC attached to VM but no public IP
            Save-CIEMGraphNode -Id '/subscriptions/sub-1/resourceGroups/rg-priv/providers/Microsoft.Network/networkInterfaces/vm-priv-nic' `
                -Kind 'AzureNIC' -DisplayName 'vm-priv-nic' -Provider 'azure' -ResourceGroup 'rg-priv'

            Save-CIEMGraphEdge -SourceId '/subscriptions/sub-1/resourceGroups/rg-priv/providers/Microsoft.Network/networkInterfaces/vm-priv-nic' `
                -TargetId '/subscriptions/sub-1/resourceGroups/rg-priv/providers/Microsoft.Compute/virtualMachines/vm-priv' `
                -Kind 'AttachedTo' -Computed 1

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'mi-nopip'
        }

        It 'Returns HostingResource with VM details' {
            $script:result.HostingResource | Should -Not -BeNullOrEmpty
            $script:result.HostingResource.Name | Should -Be 'vm-priv'
        }

        It 'HostingResource reports HasPublicIP as false' {
            $script:result.HostingResource.HasPublicIP | Should -BeFalse
        }

        It 'Does NOT include managed-identity-public-exposure signal' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'managed-identity-public-exposure' }
            $signal | Should -BeNullOrEmpty
        }
    }

    Context 'Multi-group InheritedFrom attribution picks correct group' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # User node
            Save-CIEMGraphNode -Id 'user-multi-group' -Kind 'EntraUser' -DisplayName 'Multi Group User' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    daysSinceSignIn = 3
                    lastSignIn = (Get-Date).AddDays(-3).ToString('o')
                    lastInteractiveSignIn = (Get-Date).AddDays(-3).ToString('o')
                } | ConvertTo-Json -Compress)

            # Two group nodes
            Save-CIEMGraphNode -Id 'group-readers' -Kind 'EntraGroup' -DisplayName 'Readers Group' -Provider 'azure'
            Save-CIEMGraphNode -Id 'group-owners' -Kind 'EntraGroup' -DisplayName 'Owners Group' -Provider 'azure'

            # Two scope targets (edges need unique source+target+kind)
            Save-CIEMGraphNode -Id '/subscriptions/sub-multi-1' -Kind 'AzureSubscription' -DisplayName 'Sub Multi 1' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub-multi-2' -Kind 'AzureSubscription' -DisplayName 'Sub Multi 2' -Provider 'azure'

            # MemberOf edges: user is member of BOTH groups
            Save-CIEMGraphEdge -SourceId 'user-multi-group' -TargetId 'group-readers' -Kind 'MemberOf' -Computed 0
            Save-CIEMGraphEdge -SourceId 'user-multi-group' -TargetId 'group-owners' -Kind 'MemberOf' -Computed 0

            # InheritedRole from Owners Group: Owner (privileged) on sub-1
            Save-CIEMGraphEdge -SourceId 'user-multi-group' -TargetId '/subscriptions/sub-multi-1' -Kind 'InheritedRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Owner'
                    privileged = $true
                    scope = '/subscriptions/sub-multi-1'
                    definition_id = 'role-owner'
                    inherited_from = 'group-owners'
                    inherited_from_name = 'Owners Group'
                } | ConvertTo-Json -Compress)

            # InheritedRole from Readers Group: Reader (non-privileged) on sub-2
            Save-CIEMGraphEdge -SourceId 'user-multi-group' -TargetId '/subscriptions/sub-multi-2' -Kind 'InheritedRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Reader'
                    privileged = $false
                    scope = '/subscriptions/sub-multi-2'
                    definition_id = 'role-reader'
                    inherited_from = 'group-readers'
                    inherited_from_name = 'Readers Group'
                } | ConvertTo-Json -Compress)

            $script:result = Get-CIEMIdentityRiskSignals -PrincipalId 'user-multi-group'
        }

        It 'Returns 2 inherited roles' {
            @($script:result.InheritedRoles) | Should -HaveCount 2
        }

        It 'Owner role shows InheritedFrom as Owners Group not Readers Group' {
            $ownerRole = $script:result.InheritedRoles | Where-Object { $_.RoleName -eq 'Owner' }
            $ownerRole.InheritedFrom | Should -Be 'Owners Group'
        }

        It 'Reader role shows InheritedFrom as Readers Group not Owners Group' {
            $readerRole = $script:result.InheritedRoles | Where-Object { $_.RoleName -eq 'Reader' }
            $readerRole.InheritedFrom | Should -Be 'Readers Group'
        }

        It 'Risk signal for group-inherited-privileged-role references Owners Group' {
            $signal = $script:result.RiskSignals | Where-Object { $_.Signal -eq 'group-inherited-privileged-role' }
            $signal | Should -Not -BeNullOrEmpty
            $signal.Description | Should -BeLike "*Owners Group*"
            $signal.Description | Should -Not -BeLike "*Readers Group*"
        }
    }

    Context 'Dormancy threshold boundary at exactly 90 days' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # User with daysSinceSignIn = 90 (exactly at the threshold)
            Save-CIEMGraphNode -Id 'user-boundary-90' -Kind 'EntraUser' -DisplayName 'Boundary 90 User' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    daysSinceSignIn = 90
                    lastSignIn = (Get-Date).AddDays(-90).ToString('o')
                    lastInteractiveSignIn = (Get-Date).AddDays(-90).ToString('o')
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            # Privileged role
            Save-CIEMGraphEdge -SourceId 'user-boundary-90' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-1'; definition_id = 'role-owner' } | ConvertTo-Json -Compress)

            $script:result90 = Get-CIEMIdentityRiskSignals -PrincipalId 'user-boundary-90'
        }

        It 'Does NOT trigger dormant-privileged-permissions at exactly 90 days (threshold uses -gt not -ge)' {
            $signal = $script:result90.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal | Should -BeNullOrEmpty
        }
    }

    Context 'Dormancy threshold boundary at 91 days' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # User with daysSinceSignIn = 91 (one day past the threshold)
            Save-CIEMGraphNode -Id 'user-boundary-91' -Kind 'EntraUser' -DisplayName 'Boundary 91 User' -Provider 'azure' `
                -Properties (@{
                    accountEnabled = $true
                    daysSinceSignIn = 91
                    lastSignIn = (Get-Date).AddDays(-91).ToString('o')
                    lastInteractiveSignIn = (Get-Date).AddDays(-91).ToString('o')
                } | ConvertTo-Json -Compress)

            # Scope target node
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure'

            # Privileged role
            Save-CIEMGraphEdge -SourceId 'user-boundary-91' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-1'; definition_id = 'role-owner' } | ConvertTo-Json -Compress)

            $script:result91 = Get-CIEMIdentityRiskSignals -PrincipalId 'user-boundary-91'
        }

        It 'Triggers dormant-privileged-permissions at 91 days (one day past threshold)' {
            $signal = $script:result91.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal | Should -Not -BeNullOrEmpty
            $signal.Severity | Should -Be 'Critical'
        }

        It 'Dormant signal includes DaysSinceSignIn value of 91' {
            $signal = $script:result91.RiskSignals | Where-Object { $_.Signal -eq 'dormant-privileged-permissions' }
            $signal.DaysSinceSignIn | Should -Be 91
        }
    }

    Context 'Identity not found' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
        }

        It 'Throws when PrincipalId does not exist in graph nodes' {
            { Get-CIEMIdentityRiskSignals -PrincipalId 'nonexistent-id' } | Should -Throw
        }
    }
}
