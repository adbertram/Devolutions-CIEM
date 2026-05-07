BeforeAll {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' '..' '..' '..')
    . (Join-Path $projectRoot 'psu-app' 'Tests' 'E2E' 'PesterE2EHelper.ps1')
    Initialize-PesterE2E -ProjectRoot $projectRoot

    # Test data constants — all prefixed for cleanup
    $script:TestPrefix = '_E2E_TEST_'
    $script:ProfileId1 = "_E2E_TEST_cert_$(Get-Random -Maximum 99999)"
    $script:ProfileId2 = "_E2E_TEST_cert2_$(Get-Random -Maximum 99999)"
    $script:FakeTenantId = '00000000-0000-0000-0000-000000000000'
    $script:FakeClientId = '11111111-1111-1111-1111-111111111111'

    # Verify PSU is reachable and CIEM module is loaded
    $script:psuPing = Run-OnPSU 'Get-Command Get-CIEMAzureAuthenticationProfile -ErrorAction Stop | Select-Object -ExpandProperty Name'
    if ($script:psuPing -ne 'Get-CIEMAzureAuthenticationProfile') {
        throw "Local PSU not reachable or CIEM module not loaded. Start PSU on adam-server: ssh adam-server 'sudo launchctl kickstart -k system/com.psu.server'"
    }

    # Discover real cert profile or the cert secret for connection tests
    # The cert PFX is stored in PSU vault — we need the TenantId/ClientId from an existing profile
    $realProfile = Run-OnPSU @'
        $certProfile = @(Get-CIEMAzureAuthenticationProfile -Method 'ServicePrincipalCertificate') | Select-Object -First 1
        if ($certProfile) {
            $certProfile | Select-Object Id, Name, Method, TenantId, ClientId, SecretName
        } else {
            # Fall back: check if a cert PFX exists in vault and reuse SP profile's tenant/client
            $hasCertPfx = $null -ne (Get-PSUVariable -Name 'CIEM_Azure_azure-default_CertPfx' -ErrorAction SilentlyContinue)
            $spProfile = @(Get-CIEMAzureAuthenticationProfile -Method 'ServicePrincipalSecret') | Select-Object -First 1
            if ($hasCertPfx -and $spProfile) {
                [PSCustomObject]@{
                    Id         = $null
                    Name       = $null
                    Method     = 'ServicePrincipalCertificate'
                    TenantId   = $spProfile.TenantId
                    ClientId   = $spProfile.ClientId
                    SecretName = 'CIEM_Azure_azure-default_CertPfx'
                }
            } else {
                $null
            }
        }
'@

    if (-not $realProfile -or -not $realProfile.TenantId) {
        throw "No certificate credentials found. Local PSU must have a CertPfx secret in vault and a profile with TenantId/ClientId."
    }

    $script:realCertTenantId = $realProfile.TenantId
    $script:realCertClientId = $realProfile.ClientId
    $script:realCertSecretName = if ($realProfile.SecretName) { $realProfile.SecretName } else { 'CIEM_Azure_azure-default_CertPfx' }
    $script:realCertProfileId = $realProfile.Id  # may be null if no dedicated cert profile exists

    # Validate the PFX in the vault is a real loadable certificate, not a placeholder.
    # Tests that exercise real Azure cert auth (Connect-CIEMAzure, Invoke-AzureApi with cert)
    # skip cleanly when the vault contains placeholder data — the user must upload a real PFX.
    $secretName = $script:realCertSecretName
    $script:realPfxLoadable = Run-OnPSU @"
        `$pfxBase64 = Get-CIEMSecret '$secretName'
        if (-not `$pfxBase64) { return `$false }
        try {
            `$pfxBytes = [System.Convert]::FromBase64String(`$pfxBase64)
            `$null = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(`$pfxBytes, `$null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
            `$true
        } catch {
            `$false
        }
"@

    # Save the original active profile so we can restore it
    $activeProfile = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -IsActive `$true | Select-Object -First 1 | Select-Object Id"
    $script:originalActiveProfileId = if ($activeProfile) { $activeProfile.Id } else { $null }
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

    # Restore original active profile
    if ($script:originalActiveProfileId) {
        try { Run-OnPSU "Set-CIEMAzureAuthenticationProfileActive -Id '$($script:originalActiveProfileId)'" }
        catch { Write-Warning "Failed to restore active profile: $_" }
    }
}

Describe 'Azure ServicePrincipalCertificate Authentication E2E' {

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
                    -Name '${prefix}Cert Profile' ``
                    -Method 'ServicePrincipalCertificate' ``
                    -TenantId '$tenantId' ``
                    -ClientId '$clientId' ``
                    -SecretName 'test_cert_pfx' ``
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
            $script:created.Name | Should -Be "${script:TestPrefix}Cert Profile"
        }

        It 'Profile Method is ServicePrincipalCertificate' {
            $script:created.Method | Should -Be 'ServicePrincipalCertificate'
        }

        It 'Profile TenantId matches' {
            $script:created.TenantId | Should -Be $script:FakeTenantId
        }

        It 'Profile SecretName matches' {
            $script:created.SecretName | Should -Be 'test_cert_pfx'
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
                    -Name '${prefix}Cert Get Test' ``
                    -Method 'ServicePrincipalCertificate' ``
                    -TenantId '$tenantId' -ClientId '$clientId' ``
                    -SecretName 'test_cert_pfx' ``
                    -IsActive `$false
                'seeded'
"@
            $script:byId = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id' | Select-Object Id, Name, Method, SecretName"
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

        It 'Retrieved profile has correct Method' {
            $script:byId.Method | Should -Be 'ServicePrincipalCertificate'
        }

        It 'Retrieved profile has correct SecretName' {
            $script:byId.SecretName | Should -Be 'test_cert_pfx'
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
                    -Name '${prefix}Cert Before Update' ``
                    -Method 'ServicePrincipalCertificate' ``
                    -TenantId '$tenantId' -ClientId '$($script:FakeClientId)' ``
                    -SecretName 'old_cert_pfx' ``
                    -IsActive `$false
                'seeded'
"@
            $script:updated = Run-OnPSU "Update-CIEMAzureAuthenticationProfile -Id '$id' -SecretName 'new_cert_pfx' -PassThru | Select-Object Id, Name, Method, SecretName"
        }

        AfterAll {
            $id = $script:ProfileId1
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '$id' -Confirm:`$false; 'ok'" } catch {}
        }

        It 'Returns updated profile with -PassThru' {
            $script:updated | Should -Not -BeNullOrEmpty
        }

        It 'SecretName was updated' {
            $script:updated.SecretName | Should -Be 'new_cert_pfx'
        }

        It 'Partial update preserves Method' {
            $script:updated.Method | Should -Be 'ServicePrincipalCertificate'
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
                    -Name '${prefix}Cert Save Insert' ``
                    -Method 'ServicePrincipalCertificate' ``
                    -TenantId '$tenantId' -SecretName 'test_cert_pfx' ``
                    -IsActive `$false
                'saved'
"@
            $result = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id' | Select-Object Id, Name, Method"
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "${prefix}Cert Save Insert"
            $result.Method | Should -Be 'ServicePrincipalCertificate'
        }

        It 'Upserts when profile already exists' {
            $id = $script:ProfileId1
            $tenantId = $script:FakeTenantId
            $prefix = $script:TestPrefix

            Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile ``
                    -Id '$id' -ProviderId 'Azure' ``
                    -Name '${prefix}Cert Save Upserted' ``
                    -Method 'ServicePrincipalCertificate' ``
                    -TenantId '$tenantId' -SecretName 'test_cert_pfx' ``
                    -IsActive `$false
                'saved'
"@
            $result = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id' | Select-Object Id, Name"
            $result.Name | Should -Be "${prefix}Cert Save Upserted"
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
                Save-CIEMAzureAuthenticationProfile -Id '$id1' -ProviderId 'Azure' -Name '${prefix}Cert Activate A' -Method 'ServicePrincipalCertificate' -TenantId '$tenantId' -ClientId '$clientId' -SecretName 'cert_a' -IsActive `$false
                Save-CIEMAzureAuthenticationProfile -Id '$id2' -ProviderId 'Azure' -Name '${prefix}Cert Activate B' -Method 'ServicePrincipalCertificate' -TenantId '$tenantId' -ClientId '$clientId' -SecretName 'cert_b' -IsActive `$false
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
                Save-CIEMAzureAuthenticationProfile -Id '$id' -ProviderId 'Azure' -Name '${prefix}Cert Remove Me' -Method 'ServicePrincipalCertificate' -TenantId '$tenantId' -SecretName 'cert_rm' -IsActive `$false
                'seeded'
"@
            Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '$id' -Confirm:`$false; 'removed'"
            $result = Run-OnPSU "Get-CIEMAzureAuthenticationProfile -Id '$id' | Select-Object Id"
            $result | Should -BeNullOrEmpty
        }

        It 'No-ops when removing nonexistent Id' {
            { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id 'nonexistent_cert_99999' -Confirm:`$false; 'ok'" } | Should -Not -Throw
        }
    }

    Context 'Connection with real certificate credentials' {
        BeforeAll {
            if (-not $script:realPfxLoadable) {
                $script:skipCertConnection = $true
                return
            }
            $certProfileId = '_E2E_TEST_cert_connect'
            $tenantId = $script:realCertTenantId
            $clientId = $script:realCertClientId
            $secretName = $script:realCertSecretName

            # Create a cert profile with real credentials and activate it
            Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile ``
                    -Id '$certProfileId' -ProviderId 'Azure' ``
                    -Name '_E2E_TEST_Cert Connection' ``
                    -Method 'ServicePrincipalCertificate' ``
                    -TenantId '$tenantId' -ClientId '$clientId' ``
                    -SecretName '$secretName' ``
                    -IsActive `$false
                Set-CIEMAzureAuthenticationProfileActive -Id '$certProfileId'
                'activated'
"@

            $script:connectionInfo = Run-OnPSU 'Connect-CIEMAzure | Select-Object TenantId, SubscriptionIds, AccountId, AccountType, ConnectedAt' -TimeoutSeconds 120
        }

        AfterAll {
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '_E2E_TEST_cert_connect' -Confirm:`$false; 'ok'" } catch {}
        }

        It 'Connect-CIEMAzure returns connection info' {
            if ($script:skipCertConnection) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:connectionInfo | Should -Not -BeNullOrEmpty
        }

        It 'Connection has a TenantId' {
            if ($script:skipCertConnection) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:connectionInfo.TenantId | Should -Not -BeNullOrEmpty
        }

        It 'Connection has SubscriptionIds' {
            if ($script:skipCertConnection) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:connectionInfo.SubscriptionIds | Should -Not -BeNullOrEmpty
        }

        It 'Connection has an AccountId' {
            if ($script:skipCertConnection) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:connectionInfo.AccountId | Should -Not -BeNullOrEmpty
        }

        It 'AccountType is ServicePrincipal' {
            if ($script:skipCertConnection) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:connectionInfo.AccountType | Should -Be 'ServicePrincipal'
        }
    }

    Context 'Auth context state after certificate connection' {
        BeforeAll {
            if (-not $script:realPfxLoadable) {
                $script:skipCertCtx = $true
                return
            }
            $certProfileId = '_E2E_TEST_cert_ctx'
            $tenantId = $script:realCertTenantId
            $clientId = $script:realCertClientId
            $secretName = $script:realCertSecretName

            $script:authCtx = Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile ``
                    -Id '$certProfileId' -ProviderId 'Azure' ``
                    -Name '_E2E_TEST_Cert Context' ``
                    -Method 'ServicePrincipalCertificate' ``
                    -TenantId '$tenantId' -ClientId '$clientId' ``
                    -SecretName '$secretName' ``
                    -IsActive `$false
                Set-CIEMAzureAuthenticationProfileActive -Id '$certProfileId'
                Connect-CIEMAzure | Out-Null
                `$mod = (Get-Command Connect-CIEMAzure).Module
                `$ctx = & `$mod { `$script:AzureAuthContext }
                [PSCustomObject]@{
                    IsConnected    = [bool]`$ctx.IsConnected
                    HasARMToken    = (`$null -ne `$ctx.ARMToken -and `$ctx.ARMToken.Length -gt 0)
                    HasGraphToken  = (`$null -ne `$ctx.GraphToken -and `$ctx.GraphToken.Length -gt 0)
                    Method         = `$ctx.Method
                }
"@ -TimeoutSeconds 120
        }

        AfterAll {
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '_E2E_TEST_cert_ctx' -Confirm:`$false; 'ok'" } catch {}
        }

        It 'Auth context is connected' {
            if ($script:skipCertCtx) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:authCtx.IsConnected | Should -BeTrue
        }

        It 'Auth context has ARM token' {
            if ($script:skipCertCtx) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:authCtx.HasARMToken | Should -BeTrue
        }

        It 'Auth context has Graph token' {
            if ($script:skipCertCtx) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:authCtx.HasGraphToken | Should -BeTrue
        }

        It 'Auth method is ServicePrincipalCertificate' {
            if ($script:skipCertCtx) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:authCtx.Method | Should -Be 'ServicePrincipalCertificate'
        }
    }

    Context 'Invoke-AzureApi with certificate tokens' {
        BeforeAll {
            if (-not $script:realPfxLoadable) {
                $script:skipCertApi = $true
                return
            }
            $certProfileId = '_E2E_TEST_cert_api'
            $tenantId = $script:realCertTenantId
            $clientId = $script:realCertClientId
            $secretName = $script:realCertSecretName

            $script:armResult = Run-OnPSU @"
                Save-CIEMAzureAuthenticationProfile ``
                    -Id '$certProfileId' -ProviderId 'Azure' ``
                    -Name '_E2E_TEST_Cert API' ``
                    -Method 'ServicePrincipalCertificate' ``
                    -TenantId '$tenantId' -ClientId '$clientId' ``
                    -SecretName '$secretName' ``
                    -IsActive `$false
                Set-CIEMAzureAuthenticationProfileActive -Id '$certProfileId'
                Connect-CIEMAzure | Out-Null
                `$response = Invoke-AzureApi -Api ARM -Path 'subscriptions?api-version=2022-12-01' -ResourceName 'Subscriptions'
                [PSCustomObject]@{
                    HasValue = (`$null -ne `$response)
                    Count    = @(`$response.value).Count
                }
"@ -TimeoutSeconds 120
        }

        AfterAll {
            try { Run-OnPSU "Remove-CIEMAzureAuthenticationProfile -Id '_E2E_TEST_cert_api' -Confirm:`$false; 'ok'" } catch {}
        }

        It 'ARM API call returns data' {
            if ($script:skipCertApi) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:armResult | Should -Not -BeNullOrEmpty
            $script:armResult.HasValue | Should -BeTrue
        }

        It 'ARM API returns at least one subscription' {
            if ($script:skipCertApi) { Set-ItResult -Skipped -Because 'PSU vault contains placeholder cert PFX (not a real X509 certificate)'; return }
            $script:armResult.Count | Should -BeGreaterThan 0
        }
    }
}
