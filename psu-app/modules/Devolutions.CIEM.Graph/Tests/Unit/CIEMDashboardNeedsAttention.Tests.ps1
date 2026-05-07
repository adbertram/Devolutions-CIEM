BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $graphSchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $graphSchema -Raw)
    Sync-CIEMAttackPathRuleCatalog | Out-Null

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Get-CIEMDashboardNeedsAttention' {
    Context 'Command structure' {
        It 'Is available as a public command' {
            Get-Command Get-CIEMDashboardNeedsAttention -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has -Limit parameter with ValidateRange' {
            $param = (Get-Command Get-CIEMDashboardNeedsAttention).Parameters['Limit']
            $param | Should -Not -BeNullOrEmpty
            $validateRange = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange | Should -Not -BeNullOrEmpty
        }
    }

    Context 'No risk data' {
        BeforeAll {
            Invoke-CIEMQuery -Query 'DELETE FROM attack_paths; DELETE FROM graph_edges; DELETE FROM graph_nodes;'
            $script:emptyResult = @(Get-CIEMDashboardNeedsAttention)
        }

        It 'Returns no items when there are no identity risks or attack paths' {
            $script:emptyResult | Should -HaveCount 0
        }
    }

    Context 'Identity and attack path risks exist' {
        BeforeAll {
            Invoke-CIEMQuery -Query 'DELETE FROM attack_paths; DELETE FROM graph_edges; DELETE FROM graph_nodes;'
            Sync-CIEMAttackPathRuleCatalog | Out-Null

            $now = Get-Date
            $collectedAt = $now.ToString('o')
            $oldSignIn = $now.AddDays(-120).ToString('o')
            $recentSignIn = $now.AddDays(-2).ToString('o')

            Save-CIEMGraphNode -Id 'user-critical' -Kind 'EntraUser' -DisplayName 'Dormant Admin' -Provider 'azure' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled = $true
                    daysSinceSignIn = 120
                    lastSignIn = $oldSignIn
                    lastInteractiveSignIn = $oldSignIn
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphNode -Id 'user-low' -Kind 'EntraUser' -DisplayName 'Reader User' -Provider 'azure' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    accountEnabled = $true
                    daysSinceSignIn = 2
                    lastSignIn = $recentSignIn
                    lastInteractiveSignIn = $recentSignIn
                    lastNonInteractiveSignIn = $null
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Production Subscription' `
                -Provider 'azure' -CollectedAt $collectedAt

            Save-CIEMGraphEdge -SourceId 'user-critical' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name = 'Owner'
                    privileged = $true
                    scope = '/subscriptions/sub-1'
                    definition_id = 'role-owner'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'user-low' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' `
                -CollectedAt $collectedAt `
                -Properties (@{
                    role_name = 'Reader'
                    privileged = $false
                    scope = '/subscriptions/sub-1'
                    definition_id = 'role-reader'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphNode -Id '__internet__' -Kind 'Internet' -DisplayName 'Internet' -Provider 'global' -CollectedAt $collectedAt
            Save-CIEMGraphNode -Id '/subscriptions/sub-1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg1' `
                -Kind 'AzureNSG' -DisplayName 'Public NSG' -Provider 'azure' -CollectedAt $collectedAt
            Save-CIEMGraphEdge -SourceId '__internet__' `
                -TargetId '/subscriptions/sub-1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg1' `
                -Kind 'AllowsInbound' `
                -Properties '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}' `
                -Computed 1 -CollectedAt $collectedAt

            Update-CIEMAttackPath -PatternId 'open-management-port' | Out-Null

            $rule = @(Invoke-CIEMQuery -Query "SELECT id, name, remediation, psu_script_name FROM attack_path_rules WHERE id = 'disabled-account-with-roles'")[0]
            Invoke-CIEMQuery -Query @"
INSERT INTO attack_paths (
    id, rule_id, pattern_name, severity, category, remediation, psu_script_name,
    path_json, edges_json, path_chain, evaluated_at
)
VALUES (
    'identity-attack-path', @rule_id, 'Identity attack path fixture', 'high', 'Identity', @remediation, @psu_script_name,
    @path_json, '[]', 'Dormant Admin -> Production Subscription', @evaluated_at
)
"@ -Parameters @{
                rule_id         = $rule.id
                remediation     = $rule.remediation
                psu_script_name = $rule.psu_script_name
                path_json       = @(
                    @{ id = 'user-critical'; kind = 'EntraUser'; display_name = 'Dormant Admin' }
                    @{ id = '/subscriptions/sub-1'; kind = 'AzureSubscription'; display_name = 'Production Subscription' }
                ) | ConvertTo-Json -Compress
                evaluated_at    = $collectedAt
            } -AsNonQuery | Out-Null

            $script:result = @(Get-CIEMDashboardNeedsAttention)
        }

        It 'Includes a critical identity risk item with reason, target, evidence, and drill-in URL' {
            $item = $script:result | Where-Object { $_.SourceType -eq 'Identity' -and $_.IdentityId -eq 'user-critical' }
            $item | Should -Not -BeNullOrEmpty
            $item.Severity | Should -Be 'Critical'
            $item.Identity | Should -Be 'Dormant Admin'
            $item.Target | Should -Be '/subscriptions/sub-1'
            $item.Reason | Should -Match 'Holds privileged role with no sign-in activity for 120 days'
            $item.Evidence | Should -Match '1 privileged'
            $item.DrillInUrl | Should -Be '/ciem/identities'
        }

        It 'Includes an attack path item with path evidence and drill-in URL' {
            $item = $script:result | Where-Object { $_.SourceType -eq 'AttackPath' -and $_.Title -eq 'Management port open to the internet' }
            $item | Should -Not -BeNullOrEmpty
            $item.Severity | Should -Be 'High'
            $item.Target | Should -Be 'Public NSG'
            $item.Reason | Should -Match 'Attack path exposes Public NSG'
            $item.Evidence | Should -Match 'Internet'
            $item.Evidence | Should -Match 'Public NSG'
            $item.DrillInUrl | Should -Be '/ciem/attack-paths'
        }

        It 'Includes attack path identity metadata when the path contains an identity node' {
            $item = $script:result | Where-Object { $_.SourceType -eq 'AttackPath' -and $_.Title -eq 'Identity attack path fixture' }
            $item | Should -Not -BeNullOrEmpty
            $item.Identity | Should -Be 'Dormant Admin'
            $item.IdentityId | Should -Be 'user-critical'
            $item.IdentityType | Should -Be 'User'
        }

        It 'Does not include low identity risks' {
            @($script:result | Where-Object { $_.IdentityId -eq 'user-low' }) | Should -HaveCount 0
        }

        It 'Sorts critical identity risks before high attack paths' {
            $script:result[0].SourceType | Should -Be 'Identity'
            $script:result[0].Severity | Should -Be 'Critical'
        }

        It 'Honors the -Limit parameter' {
            @(Get-CIEMDashboardNeedsAttention -Limit 1) | Should -HaveCount 1
        }
    }
}
