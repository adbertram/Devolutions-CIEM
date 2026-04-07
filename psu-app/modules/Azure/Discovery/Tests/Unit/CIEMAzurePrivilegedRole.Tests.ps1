BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'TestCIEMAzurePrivilegedRole' {

    It 'Is available as a private function inside the module' {
        InModuleScope Devolutions.CIEM {
            Get-Command TestCIEMAzurePrivilegedRole -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Known privileged role names (data-driven from privileged_roles.json)' {

        $rolesJson = Join-Path $PSScriptRoot '..' '..' 'Data' 'privileged_roles.json'
        $allPrivilegedRoles = (Get-Content $rolesJson -Raw | ConvertFrom-Json) | ForEach-Object {
            @{ RoleName = $_.name; Category = $_.category }
        }

        It 'Returns true for <RoleName> (<Category>)' -TestCases $allPrivilegedRoles {
            InModuleScope Devolutions.CIEM -Parameters @{ RoleName = $RoleName } {
                TestCIEMAzurePrivilegedRole -RoleName $RoleName | Should -BeTrue
            }
        }

        It 'Returns false for Reader' {
            InModuleScope Devolutions.CIEM {
                TestCIEMAzurePrivilegedRole -RoleName 'Reader' | Should -BeFalse
            }
        }

        It 'Returns false for custom non-privileged role' {
            InModuleScope Devolutions.CIEM {
                TestCIEMAzurePrivilegedRole -RoleName 'My Custom Reader Role' | Should -BeFalse
            }
        }
    }

    Context 'Wildcard permission detection' {

        It 'Returns true for role with star action' {
            InModuleScope Devolutions.CIEM {
                $perms = @(@{ actions = @('*'); notActions = @() }) | ConvertTo-Json -Compress
                TestCIEMAzurePrivilegedRole -RoleName 'Custom Full Access' -PermissionsJson $perms | Should -BeTrue
            }
        }

        It 'Returns true for role with role assignment write' {
            InModuleScope Devolutions.CIEM {
                $perms = @(@{ actions = @('Microsoft.Authorization/roleAssignments/write'); notActions = @() }) | ConvertTo-Json -Compress
                TestCIEMAzurePrivilegedRole -RoleName 'Custom RBAC Manager' -PermissionsJson $perms | Should -BeTrue
            }
        }

        It 'Returns true for role with authorization wildcard' {
            InModuleScope Devolutions.CIEM {
                $perms = @(@{ actions = @('Microsoft.Authorization/*'); notActions = @() }) | ConvertTo-Json -Compress
                TestCIEMAzurePrivilegedRole -RoleName 'Custom Auth Manager' -PermissionsJson $perms | Should -BeTrue
            }
        }

        It 'Returns false for role with only read actions' {
            InModuleScope Devolutions.CIEM {
                $perms = @(@{ actions = @('*/read'); notActions = @() }) | ConvertTo-Json -Compress
                TestCIEMAzurePrivilegedRole -RoleName 'Custom Reader' -PermissionsJson $perms | Should -BeFalse
            }
        }

        It 'Returns false when PermissionsJson is null' {
            InModuleScope Devolutions.CIEM {
                TestCIEMAzurePrivilegedRole -RoleName 'Custom Role' -PermissionsJson $null | Should -BeFalse
            }
        }

        It 'Returns false when PermissionsJson is empty' {
            InModuleScope Devolutions.CIEM {
                TestCIEMAzurePrivilegedRole -RoleName 'Custom Role' -PermissionsJson '' | Should -BeFalse
            }
        }

        It 'Throws on malformed JSON instead of silently returning false' {
            InModuleScope Devolutions.CIEM {
                { TestCIEMAzurePrivilegedRole -RoleName 'Custom Role' -PermissionsJson '{not valid json' } | Should -Throw
            }
        }
    }

    Context 'Pipeline input with effective role assignments' {

        It 'Processes an array of assignments and returns boolean per item' {
            InModuleScope Devolutions.CIEM {
                $assignments = @(
                    [PSCustomObject]@{ RoleName = 'Owner'; PermissionsJson = $null }
                    [PSCustomObject]@{ RoleName = 'Reader'; PermissionsJson = $null }
                    [PSCustomObject]@{ RoleName = 'Contributor'; PermissionsJson = $null }
                )
                $results = $assignments | ForEach-Object {
                    TestCIEMAzurePrivilegedRole -RoleName $_.RoleName -PermissionsJson $_.PermissionsJson
                }
                $results[0] | Should -BeTrue
                $results[1] | Should -BeFalse
                $results[2] | Should -BeTrue
            }
        }
    }
}
