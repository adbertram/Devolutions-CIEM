BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

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

Describe 'Attack Path persistence' {
    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM attack_paths'
        Invoke-CIEMQuery -Query 'DELETE FROM attack_path_rules'
        Invoke-CIEMQuery -Query 'DELETE FROM graph_edges'
        Invoke-CIEMQuery -Query 'DELETE FROM graph_nodes'
    }

    Context 'database schema' {
        It 'creates attack_path_rules and attack_paths tables' {
            $tables = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('attack_path_rules', 'attack_paths') ORDER BY name")
            $tables.name | Should -Contain 'attack_path_rules'
            $tables.name | Should -Contain 'attack_paths'
        }

        It 'stores the PSU script reference on attack path rules' {
            $columns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('attack_path_rules')")
            $columnNames = @($columns | ForEach-Object { $_.name })
            $columnNames | Should -Contain 'psu_script_name'
            $columnNames | Should -Contain 'steps_json'
        }

        It 'stores materialized path and edge JSON on attack paths' {
            $columns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('attack_paths')")
            $columnNames = @($columns | ForEach-Object { $_.name })
            $columnNames | Should -Contain 'path_json'
            $columnNames | Should -Contain 'edges_json'
            $columnNames | Should -Contain 'path_chain'
        }
    }

    Context 'rule catalog sync' {
        It 'stores shipped attack path rules in the database with PSU script names' {
            $result = Sync-CIEMAttackPathRuleCatalog

            $result.Status | Should -Be 'Synced'
            $result.RuleCount | Should -BeGreaterOrEqual 10

            $row = Invoke-CIEMQuery -Query "SELECT id, name, psu_script_name, steps_json FROM attack_path_rules WHERE id = @id" -Parameters @{ id = 'open-management-port' }
            $row.id | Should -Be 'open-management-port'
            $row.name | Should -Be 'Management port open to the internet'
            $row.psu_script_name | Should -Be 'management-port-open-to-the-internet'
            $row.steps_json | Should -Match 'AllowsInbound'
        }

        It 'returns attack path patterns from the database rule catalog' {
            Sync-CIEMAttackPathRuleCatalog | Out-Null

            $pattern = Get-CIEMAttackPathPattern | Where-Object Id -eq 'open-management-port'

            $pattern | Should -Not -BeNullOrEmpty
            $pattern.GetType().Name | Should -Be 'CIEMAttackPathRule'
            $pattern.StepCount | Should -Be 3
            $pattern.PsuScriptName | Should -Be 'management-port-open-to-the-internet'
            $pattern.RemediationScriptPath | Should -Be 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/management-port-open-to-the-internet.ps1'
        }
    }

    Context 'attack path materialization' {
        BeforeEach {
            Sync-CIEMAttackPathRuleCatalog | Out-Null
            Save-CIEMGraphNode -Id '__internet__' -Kind 'Internet' -DisplayName 'Internet' -Provider 'global'
            Save-CIEMGraphNode -Id '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg1' -Kind 'AzureNSG' -DisplayName 'nsg1' -Provider 'azure'
            Save-CIEMGraphEdge -SourceId '__internet__' -TargetId '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg1' -Kind 'AllowsInbound' `
                -Properties '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}' -Computed 1
        }

        It 'materializes evaluated attack paths into attack_paths' {
            $result = @(Update-CIEMAttackPath -PatternId 'open-management-port' -PassThru)

            $result | Should -HaveCount 1
            $result[0].GetType().Name | Should -Be 'CIEMAttackPath'
            $result[0].PatternId | Should -Be 'open-management-port'
            $result[0].PsuScriptName | Should -Be 'management-port-open-to-the-internet'
            $result[0].PathChain | Should -Match 'Internet'
            $result[0].PathChain | Should -Match 'nsg1'

            $row = Invoke-CIEMQuery -Query 'SELECT rule_id, path_json, edges_json, path_chain FROM attack_paths WHERE id = @id' -Parameters @{ id = $result[0].Id }
            $row.rule_id | Should -Be 'open-management-port'
            $row.path_json | Should -Match 'AzureNSG'
            $row.edges_json | Should -Match 'AllowsInbound'
            $row.path_chain | Should -Be $result[0].PathChain
        }

        It 'returns stored attack paths without re-evaluating the graph' {
            Update-CIEMAttackPath -PatternId 'open-management-port' | Out-Null
            Invoke-CIEMQuery -Query 'DELETE FROM graph_edges'
            Invoke-CIEMQuery -Query 'DELETE FROM graph_nodes'

            $stored = @(Get-CIEMAttackPath -PatternId 'open-management-port')

            $stored | Should -HaveCount 1
            $stored[0].PatternId | Should -Be 'open-management-port'
            $stored[0].PathChain | Should -Match 'Internet'
            $stored[0].RemediationScript | Should -BeNullOrEmpty
        }

        It 'removes stale stored attack paths when refreshed' {
            Update-CIEMAttackPath -PatternId 'open-management-port' | Out-Null
            Invoke-CIEMQuery -Query 'DELETE FROM graph_edges'

            $result = @(Update-CIEMAttackPath -PatternId 'open-management-port' -PassThru)
            $stored = @(Get-CIEMAttackPath -PatternId 'open-management-port')

            $result | Should -HaveCount 0
            $stored | Should -HaveCount 0
        }
    }

    Context 'PSU remediation script rendering' {
        BeforeEach {
            Sync-CIEMAttackPathRuleCatalog | Out-Null
            Save-CIEMGraphNode -Id '__internet__' -Kind 'Internet' -DisplayName 'Internet' -Provider 'global'
            Save-CIEMGraphNode -Id '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg1' -Kind 'AzureNSG' -DisplayName 'nsg1' -Provider 'azure'
            Save-CIEMGraphEdge -SourceId '__internet__' -TargetId '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg1' -Kind 'AllowsInbound' `
                -Properties '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}' -Computed 1
            $script:StoredAttackPath = @(Update-CIEMAttackPath -PatternId 'open-management-port' -PassThru)[0]
        }

        It 'reads the PSU script by rule reference and replaces attack path, auth profile, and PSU environment placeholders' {
            Mock -ModuleName Devolutions.CIEM Get-PSUScript {
                [pscustomobject]@{
                    Name    = $Name
                    Content = @'
# {{PATTERN_NAME}}
# {{PATH_CHAIN}}
# {{AUTH_PROFILE_ID}}
# {{AUTH_PROFILE_NAME}}
# {{AUTH_PROFILE_METHOD}}
# {{TENANT_ID}}
# {{CLIENT_ID}}
# {{MANAGED_IDENTITY_CLIENT_ID}}
# {{PSU_ENVIRONMENT}}
# {{PSU_WEBSITE_NAME}}
{{NSG_RULE_DELETE_COMMANDS}}
'@
                }
            }
            Mock -ModuleName Devolutions.CIEM Get-CIEMAzureAuthenticationProfile {
                [pscustomobject]@{
                    Id                      = 'profile-1'
                    Name                    = 'Production'
                    Method                  = 'ServicePrincipalSecret'
                    TenantId                = 'tenant-1'
                    ClientId                = 'client-1'
                    ManagedIdentityClientId = 'mi-client-1'
                }
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUInstalledEnvironment {
                [pscustomobject]@{
                    Environment             = 'AzureWebApp'
                    SupportsManagedIdentity = $true
                    WebsiteName             = 'ciem-prod'
                }
            }

            $scriptText = Get-CIEMAttackPathRemediationScript -Id $script:StoredAttackPath.Id

            $scriptText | Should -Match '# Management port open to the internet'
            $scriptText | Should -Match 'Internet \(Internet\)'
            $scriptText | Should -Match '# profile-1'
            $scriptText | Should -Match '# Production'
            $scriptText | Should -Match '# ServicePrincipalSecret'
            $scriptText | Should -Match '# tenant-1'
            $scriptText | Should -Match '# client-1'
            $scriptText | Should -Match '# mi-client-1'
            $scriptText | Should -Match '# AzureWebApp'
            $scriptText | Should -Match '# ciem-prod'
            $scriptText | Should -Match 'az network nsg rule delete'
            $scriptText | Should -Not -Match '{{'
            Should -Invoke -CommandName Get-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
                $Name -eq 'management-port-open-to-the-internet' -and $Integrated
            }
        }
    }
}
