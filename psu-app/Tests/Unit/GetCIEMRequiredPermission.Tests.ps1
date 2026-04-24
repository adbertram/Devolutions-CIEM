BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    $script:RemediationPermissionCatalogPath = Join-Path $PSScriptRoot '..' '..' 'modules' 'Devolutions.CIEM.Checks' 'Data' 'remediation-permissions.json'
    $script:RemediationPermissionCatalog = Get-Content $script:RemediationPermissionCatalogPath -Raw | ConvertFrom-Json -AsHashtable
}

Describe 'Get-CIEMRequiredPermission' {

    Context 'when Azure discovery endpoints and remediation templates are available' {

        BeforeAll {
            $tokens = @(
                'NSG_RULE_DELETE_COMMANDS',
                'ROLE_ASSIGNMENT_DELETE_COMMANDS',
                'GROUP_MEMBER_REMOVE_COMMANDS'
            )
            $script:ExpectedRemediationGraph = @(
                foreach ($token in $tokens) {
                    foreach ($permission in @($script:RemediationPermissionCatalog.Azure.RemediationTokens[$token].Graph)) {
                        $permission
                    }
                }
            ) | Select-Object -Unique | Sort-Object
            $script:ExpectedRemediationAzureRoles = @(
                foreach ($token in $tokens) {
                    foreach ($role in @($script:RemediationPermissionCatalog.Azure.RemediationTokens[$token].AzureRoles)) {
                        $role
                    }
                }
            ) | Select-Object -Unique | Sort-Object

            Mock -ModuleName Devolutions.CIEM Get-CIEMCheck { @() }

            Mock -ModuleName Devolutions.CIEM GetCIEMAzureProviderApi {
                @(
                    [pscustomobject]@{
                        Permissions = [pscustomobject]@{
                            Graph      = @('Directory.Read.All', 'AuditLog.Read.All')
                            AzureRoles = @('Reader')
                        }
                    }
                )
            }

            Mock -ModuleName Devolutions.CIEM Get-ChildItem {
                @(
                    [pscustomobject]@{ FullName = '/mock/management-port-open-to-the-internet.ps1' }
                    [pscustomobject]@{ FullName = '/mock/service-principal-holding-owner-role-on-a-subscription.ps1' }
                    [pscustomobject]@{ FullName = '/mock/guest-user-is-a-member-of-a-group-that-holds-a-privileged-role.ps1' }
                )
            } -ParameterFilter { $Path -like '*attack_path_remediation_scripts*' -and $File }

            Mock -ModuleName Devolutions.CIEM Get-Content {
                if ($Path -eq '/mock/management-port-open-to-the-internet.ps1') {
                    return @'
{{NSG_RULE_DELETE_COMMANDS}}
'@
                }

                if ($Path -eq '/mock/service-principal-holding-owner-role-on-a-subscription.ps1') {
                    return @'
{{ROLE_ASSIGNMENT_DELETE_COMMANDS}}
'@
                }

                if ($Path -eq '/mock/guest-user-is-a-member-of-a-group-that-holds-a-privileged-role.ps1') {
                    return @'
{{GROUP_MEMBER_REMOVE_COMMANDS}}
'@
                }

                Microsoft.PowerShell.Management\Get-Content -Path $Path -Raw:$Raw
            }
        }

        It 'returns discovery and remediation permissions as separate sections' {
            $result = Get-CIEMRequiredPermission -Provider Azure

            $result.Discovery | Should -Not -BeNullOrEmpty
            $result.Remediation | Should -Not -BeNullOrEmpty
        }

        It 'keeps discovery requirements scoped to discovery reads' {
            $result = Get-CIEMRequiredPermission -Provider Azure

            $result.Discovery.Graph | Should -Contain 'AuditLog.Read.All'
            $result.Discovery.Graph | Should -Contain 'Directory.Read.All'
            $result.Discovery.AzureRoles | Should -Contain 'Reader'
            $result.Discovery.AzureRoles | Should -Not -Contain 'Network Contributor'
            $result.Discovery.AzureRoles | Should -Not -Contain 'User Access Administrator'
        }

        It 'reports remediation write permissions separately from discovery permissions' {
            $result = Get-CIEMRequiredPermission -Provider Azure

            $result.Remediation.Graph | Should -Be $script:ExpectedRemediationGraph
            $result.Remediation.AzureRoles | Should -Be $script:ExpectedRemediationAzureRoles
            $result.Remediation.AzureRoles | Should -Not -Contain 'Reader'
            $result.Remediation.TemplateCount | Should -Be 3
        }
    }
}
