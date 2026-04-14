BeforeAll {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' '..' '..' '..')
    . (Join-Path $projectRoot 'psu-app' 'Tests' 'E2E' 'PesterE2EHelper.ps1')
    Initialize-PesterE2E -ProjectRoot $projectRoot

    # Test data constants — all prefixed for cleanup
    $script:TestPrefix = '_E2E_TEST_'
    $script:ProfileId1 = "_E2E_TEST_sp_$(Get-Random -Maximum 99999)"
    $script:ProfileId2 = "_E2E_TEST_sp2_$(Get-Random -Maximum 99999)"
    $script:FakeTenantId = '00000000-0000-0000-0000-000000000000'
    $script:FakeClientId = '11111111-1111-1111-1111-111111111111'

    # Verify PSU is reachable and CIEM module is loaded
    $script:psuPing = Run-OnPSU 'Get-Command Get-CIEMAzureAuthenticationProfile -ErrorAction Stop | Select-Object -ExpandProperty Name'
    if ($script:psuPing -ne 'Get-CIEMAzureAuthenticationProfile') {
        throw "Local PSU not reachable or CIEM module not loaded. Start PSU on adam-server: ssh adam-server 'sudo launchctl kickstart -k system/com.psu.server'"
    }

    # Verify a real SP profile exists for connection tests
    $realProfile = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Method 'ServicePrincipalSecret' | Select-Object -First 1 | Select-Object Id, Name, Method"
    if (-not $realProfile -or -not $realProfile.Id) {
        throw "No ServicePrincipalSecret auth profile found. Local PSU must have real Azure SP credentials configured."
    }
    $script:realProfileId = $realProfile.Id
}

AfterAll {
    $prefix = $script:TestPrefix
    try {
        Run-OnPSU @"
            @(Get-CIEMAzureAuthenticationProfile) | Where-Object { `$_.Id -like '${prefix}*' } | ForEach-Object {
                Remove-CIEMAzureAuthenticationProfile -Id `$_.Id -Confirm:`$false
            }
            'cleanup_done'
"@
    }
    catch { Write-Warning "E2E cleanup failed: $_" }

    if ($script:realProfileId) {
        try { Run-OnPSU "Set-CIEMAzureAuthenticationProfileActive -Id '$($script:realProfileId)'" }
        catch { Write-Warning "Failed to restore active profile: $_" }
    }
}

Describe 'Azure ServicePrincipalSecret Authentication E2E' {

    Context 'PSU health check' {
        It 'CIEM module is loaded and functions are available' {
            $script:psuPing | Should -Be 'Get-CIEMAzureAuthenticationProfile'
        }
    }

    Context 'Profile Create' {
        BeforeAll {
            $id = $script:ProfileId1
            $tenantId = $script:FakeTenantId
            $clientId = $script:FakeClientId
            $prefix = $script:TestPrefix

            $script:created = Run-OnPSU @"
                New-CIEMAzureAuthenticationProfile ``
                    -Id '$id' ``
                    -ProviderId 'Azure' ``
                    -Name '${prefix}SP Profile' ``
                    -Method 'ServicePrincipalSecret' ``
                    -TenantId '$tenantId' ``
                    -ClientId '$clientId' ``
                    -IsActive `$false
"@
        }

        AfterAll {
            $id = $script:ProfileId1
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '$id' -Confirm:`$false; 'ok'" } catch {}
        }

        It 'Returns a profile object' {
            $script:created | Should -Not -BeNullOrEmpty
        }

        It 'Profile Id matches requested value' {
            $script:created.Id | Should -Be $script:ProfileId1
        }

        It 'Profile Name matches requested value' {
            $script:created.Name | Should -Be "${script:TestPrefix}SP Profile"
        }

        It 'Profile Method is ServicePrincipalSecret' {
            $script:created.Method | Should -Be 'ServicePrincipalSecret'
        }

        It 'Profile TenantId matches' {
            $script:created.TenantId | Should -Be $script:FakeTenantId
        }

        It 'Profile ClientId matches' {
            $script:created.ClientId | Should -Be $script:FakeClientId
        }
    }

    Context 'Profile Get by Id' {
        BeforeAll {
            $id = $script:ProfileId1
            $tenantId = $script:FakeTenantId
            $clientId = $script:FakeClientId
            $prefix = $script:TestPrefix

            Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile ``
                    -Id '$id' -ProviderId 'Azure' ``
                    -Name '${prefix}Get Test' ``
                    -Method 'ServicePrincipalSecret' ``
                    -TenantId '$tenantId' -ClientId '$clientId' ``
                    -IsActive `$false
                'seeded'
"@
            $script:byId = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id' | Select-Object Id, Name, Method, TenantId"
        }

        AfterAll {
            $id = $script:ProfileId1
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '$id' -Confirm:`$false; 'ok'" } catch {}
        }

        It 'Retrieves profile by Id' {
            $script:byId | Should -Not -BeNullOrEmpty
        }

        It 'Retrieved profile has correct Id' {
            $script:byId.Id | Should -Be $script:ProfileId1
        }

        It 'Retrieved profile has correct Name' {
            $script:byId.Name | Should -Be "${script:TestPrefix}Get Test"
        }

        It 'Returns empty for nonexistent Id' {
            $result = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id 'nonexistent_xyz_99999' | Select-Object Id"
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Profile Update' {
        BeforeAll {
            $id = $script:ProfileId1
            $tenantId = $script:FakeTenantId
            $prefix = $script:TestPrefix

            Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile ``
                    -Id '$id' -ProviderId 'Azure' ``
                    -Name '${prefix}Before Update' ``
                    -Method 'ServicePrincipalSecret' ``
                    -TenantId '$tenantId' -ClientId '$($script:FakeClientId)' ``
                    -IsActive `$false
                'seeded'
"@
            $script:updated = Run-OnPSU "Update-CIEMAzureAuthenticationProfile -Id '$id' -Name '${prefix}After Update' -PassThru | Select-Object Id, Name, Method, TenantId"
        }

        AfterAll {
            $id = $script:ProfileId1
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '$id' -Confirm:`$false; 'ok'" } catch {}
        }

        It 'Returns updated profile with -PassThru' {
            $script:updated | Should -Not -BeNullOrEmpty
        }

        It 'Name was updated' {
            $script:updated.Name | Should -Be "${script:TestPrefix}After Update"
        }

        It 'Partial update preserves Method' {
            $script:updated.Method | Should -Be 'ServicePrincipalSecret'
        }

        It 'Partial update preserves TenantId' {
            $script:updated.TenantId | Should -Be $script:FakeTenantId
        }
    }

    Context 'Profile Save (Upsert)' {
        AfterAll {
            $id = $script:ProfileId1
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '$id' -Confirm:`$false; 'ok'" } catch {}
        }

        It 'Inserts when profile does not exist' {
            $id = $script:ProfileId1
            $tenantId = $script:FakeTenantId
            $prefix = $script:TestPrefix

            Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile ``
                    -Id '$id' -ProviderId 'Azure' ``
                    -Name '${prefix}Save Insert' ``
                    -Method 'ServicePrincipalSecret' ``
                    -TenantId '$tenantId' -IsActive `$false
                'saved'
"@
            $result = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id' | Select-Object Id, Name"
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "${prefix}Save Insert"
        }

        It 'Upserts when profile already exists' {
            $id = $script:ProfileId1
            $tenantId = $script:FakeTenantId
            $prefix = $script:TestPrefix

            Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile ``
                    -Id '$id' -ProviderId 'Azure' ``
                    -Name '${prefix}Save Upserted' ``
                    -Method 'ServicePrincipalSecret' ``
                    -TenantId '$tenantId' -IsActive `$false
                'saved'
"@
            $result = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id' | Select-Object Id, Name"
            $result.Name | Should -Be "${prefix}Save Upserted"
        }
    }

    Context 'Profile Activation' {
        BeforeAll {
            $id1 = $script:ProfileId1
            $id2 = $script:ProfileId2
            $tenantId = $script:FakeTenantId
            $clientId = $script:FakeClientId
            $prefix = $script:TestPrefix

            Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile -Id '$id1' -ProviderId 'Azure' -Name '${prefix}Activate A' -Method 'ServicePrincipalSecret' -TenantId '$tenantId' -ClientId '$clientId' -IsActive `$false
                Save-CIEMAzureAuthenticationProfile -Id '$id2' -ProviderId 'Azure' -Name '${prefix}Activate B' -Method 'ServicePrincipalSecret' -TenantId '$tenantId' -ClientId '$clientId' -IsActive `$false
                'seeded'
"@

            Run-OnPSU "Set-CIEMAzureAuthenticationProfileActive -Id '$id1'; 'activated'"
            $script:p1after1 = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id1' | Select-Object Id, IsActive"
            $script:p2after1 = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id2' | Select-Object Id, IsActive"

            Run-OnPSU "Set-CIEMAzureAuthenticationProfileActive -Id '$id2'; 'activated'"
            $script:p1after2 = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id1' | Select-Object Id, IsActive"
            $script:p2after2 = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id2' | Select-Object Id, IsActive"
        }

        AfterAll {
            $id1 = $script:ProfileId1
            $id2 = $script:ProfileId2
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '$id1' -Confirm:`$false; 'ok'" } catch {}
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '$id2' -Confirm:`$false; 'ok'" } catch {}
        }

        It 'Profile 1 is active after first activation' {
            $script:p1after1.IsActive | Should -BeTrue
        }

        It 'Profile 2 is inactive after first activation' {
            $script:p2after1.IsActive | Should -BeFalse
        }

        It 'Profile 2 is active after second activation' {
            $script:p2after2.IsActive | Should -BeTrue
        }

        It 'Profile 1 is deactivated after second activation' {
            $script:p1after2.IsActive | Should -BeFalse
        }
    }

    Context 'Profile Remove' {
        It 'Removes profile by Id' {
            $id = $script:ProfileId1
            $tenantId = $script:FakeTenantId
            $prefix = $script:TestPrefix

            Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile -Id '$id' -ProviderId 'Azure' -Name '${prefix}Remove Me' -Method 'ServicePrincipalSecret' -TenantId '$tenantId' -IsActive `$false
                'seeded'
"@
            Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '$id' -Confirm:`$false; 'removed'"
            $result = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id' | Select-Object Id"
            $result | Should -BeNullOrEmpty
        }

        It 'No-ops when removing nonexistent Id' {
            { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id 'nonexistent_xyz_99999' -Confirm:`$false; 'ok'" } | Should -Not -Throw
        }
    }

    Context 'Connection with real SP credentials' {
        BeforeAll {
            $realId = $script:realProfileId
            Run-OnPSU "Set-CIEMAzureAuthenticationProfileActive -Id '$realId'; 'activated'"

            $script:connectionInfo = Run-OnPSU 'Connect-CIEMAzure | Select-Object TenantId, SubscriptionIds, AccountId, AccountType, ConnectedAt' -TimeoutSeconds 120
        }

        It 'Connect-CIEMAzure returns connection info' {
            $script:connectionInfo | Should -Not -BeNullOrEmpty
        }

        It 'Connection has a TenantId' {
            $script:connectionInfo.TenantId | Should -Not -BeNullOrEmpty
        }

        It 'Connection has SubscriptionIds' {
            $script:connectionInfo.SubscriptionIds | Should -Not -BeNullOrEmpty
        }

        It 'Connection has an AccountId' {
            $script:connectionInfo.AccountId | Should -Not -BeNullOrEmpty
        }

        It 'AccountType is ServicePrincipal' {
            $script:connectionInfo.AccountType | Should -Be 'ServicePrincipal'
        }
    }

    Context 'Auth context state after SP connection' {
        BeforeAll {
            $script:authCtx = Run-OnPSU @'
                Connect-CIEMAzure | Out-Null
                $mod = (Get-Command Connect-CIEMAzure).Module
                $ctx = & $mod { $script:AzureAuthContext }
                [PSCustomObject]@{
                    IsConnected    = [bool]$ctx.IsConnected
                    HasARMToken    = ($null -ne $ctx.ARMToken -and $ctx.ARMToken.Length -gt 0)
                    HasGraphToken  = ($null -ne $ctx.GraphToken -and $ctx.GraphToken.Length -gt 0)
                    Method         = $ctx.Method
                }
'@ -TimeoutSeconds 120
        }

        It 'Auth context is connected' {
            $script:authCtx.IsConnected | Should -BeTrue
        }

        It 'Auth context has ARM token' {
            $script:authCtx.HasARMToken | Should -BeTrue
        }

        It 'Auth context has Graph token' {
            $script:authCtx.HasGraphToken | Should -BeTrue
        }

        It 'Auth method is ServicePrincipalSecret' {
            $script:authCtx.Method | Should -Be 'ServicePrincipalSecret'
        }
    }

    Context 'Invoke-AzureApi with SP tokens' {
        BeforeAll {
            $script:armResult = Run-OnPSU @'
                Connect-CIEMAzure | Out-Null
                $response = Invoke-AzureApi -Api ARM -Path 'subscriptions?api-version=2022-12-01' -ResourceName 'Subscriptions'
                [PSCustomObject]@{
                    HasValue = ($null -ne $response)
                    Count    = @($response.value).Count
                }
'@ -TimeoutSeconds 120
        }

        It 'ARM API call returns data' {
            $script:armResult | Should -Not -BeNullOrEmpty
            $script:armResult.HasValue | Should -BeTrue
        }

        It 'ARM API returns at least one subscription' {
            $script:armResult.Count | Should -BeGreaterThan 0
        }
    }
}
