BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    $modulePsd1 = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1'
    Import-Module $modulePsd1

    # Checks/ files are not loaded at module init; dot-source the check at outer test
    # scope so we can call it directly. Load classes here too so [CIEMScanResult]
    # resolves at the call site.
    $script:CheckPath = Join-Path $PSScriptRoot '..' '..' 'Test-IamCustomRoleHasPermissionToAdministerResourceLock.ps1'
    $checksRoot = Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.Checks' 'Classes'
    foreach ($className in @('CIEMCheck', 'CIEMScanResult', 'CIEMServiceCache')) {
        $classFile = Join-Path $checksRoot "$className.ps1"
        if (Test-Path $classFile) { . $classFile }
    }
    . $script:CheckPath

    # PSCustomObject is sufficient; CIEMScanResult::Create accepts [object] for the check.
    $script:testCheck = [pscustomobject]@{
        Id       = 'iam_custom_role_has_permission_to_administer_resource_lock'
        Service  = 'IAM'
        Severity = 'medium'
        Provider = 'Azure'
        Title    = 'Custom role lock administration'
    }
}

Describe 'Test-IamCustomRoleHasPermissionToAdministerResourceLock' {
    Context 'when a custom role has no properties field at all' {
        # Real-world repro: ConvertFromCIEMStoredResource can produce role hashtables
        # without a 'properties' key. Line 93 then dereferences $null.PSObject.Properties
        # which throws "Cannot index into a null array" at parameter binding time.
        It 'returns a result instead of throwing "Cannot index into a null array"' {
            $roleWithoutProperties = [pscustomobject]@{
                id = '/subscriptions/sub-1/providers/Microsoft.Authorization/roleDefinitions/abc'
                type = 'CustomRole'
            }
            $cache = [pscustomobject]@{
                ServiceName = 'IAM'
                Success = $true
                CacheData = @{ 'sub-1' = @{ RoleDefinitions = @($roleWithoutProperties); CustomRoles = @($roleWithoutProperties) } }
            }

            { Test-IamCustomRoleHasPermissionToAdministerResourceLock -Check $script:testCheck -ServiceCache @($cache) } |
                Should -Not -Throw

            $result = Test-IamCustomRoleHasPermissionToAdministerResourceLock -Check $script:testCheck -ServiceCache @($cache)
            @($result) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when a custom role has properties but no permissions field' {
        It 'still completes without throwing' {
            $roleNoPerms = [pscustomobject]@{
                id = '/subscriptions/sub-1/providers/Microsoft.Authorization/roleDefinitions/xyz'
                type = 'CustomRole'
                properties = [pscustomobject]@{ roleName = 'No Permissions Role' }
            }
            $cache = [pscustomobject]@{
                ServiceName = 'IAM'
                Success = $true
                CacheData = @{ 'sub-1' = @{ RoleDefinitions = @($roleNoPerms); CustomRoles = @($roleNoPerms) } }
            }

            { Test-IamCustomRoleHasPermissionToAdministerResourceLock -Check $script:testCheck -ServiceCache @($cache) } |
                Should -Not -Throw
        }
    }

    Context 'when a custom role has lock administration permissions' {
        It 'emits a PASS result' {
            # Roles arrive as PSCustomObject from ConvertFromCIEMStoredResource (ConvertFrom-Json output);
            # the check function uses .PSObject.Properties[...] which works on PSCustomObject, not hashtable.
            $roleWithLock = [pscustomobject]@{
                id = '/subscriptions/sub-1/providers/Microsoft.Authorization/roleDefinitions/lock-admin'
                type = 'CustomRole'
                properties = [pscustomobject]@{
                    roleName = 'Lock Administrator'
                    permissions = @([pscustomobject]@{ actions = @('Microsoft.Authorization/locks/*') })
                }
            }
            $cache = [pscustomobject]@{
                ServiceName = 'IAM'
                Success = $true
                CacheData = @{ 'sub-1' = @{ RoleDefinitions = @($roleWithLock); CustomRoles = @($roleWithLock) } }
            }

            $result = Test-IamCustomRoleHasPermissionToAdministerResourceLock -Check $script:testCheck -ServiceCache @($cache)
            @($result) | Should -HaveCount 1
            @($result)[0].Status.ToString() | Should -Be 'PASS'
        }
    }
}
