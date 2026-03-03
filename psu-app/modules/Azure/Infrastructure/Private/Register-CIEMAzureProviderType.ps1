function Register-CIEMAzureProviderType {
    <#
    .SYNOPSIS
        Registers the Azure provider type with the CIEM Base module.

    .DESCRIPTION
        Calls Register-CIEMProviderType to register Azure-specific callbacks for
        authentication, database persistence, connectivity testing, and default seeding.

        This function is called during Azure module initialization (after schema
        application) so that Base's provider CRUD functions know how to handle
        Azure providers.
    #>
    [CmdletBinding()]
    param()

    $callbacks = @{

        # -- Default API endpoints --
        DefaultEndpoints = {
            [PSCustomObject]@{
                graphApi = 'https://graph.microsoft.com/v1.0'
                armApi   = 'https://management.azure.com'
            }
        }

        # -- QueryAuth: JOIN via auth_profile_id FK --
        QueryAuth = {
            @{
                Columns    = "ap.name AS auth_profile_name, ap.method AS auth_method, ap.tenant_id AS auth_tenant_id, ap.client_id AS auth_client_id"
                JoinClause = "LEFT JOIN azure_authentication_profiles ap ON ap.id = p.auth_profile_id"
            }
        }

        # -- ReadAuth: Return display info from query row (includes TenantId/ClientId from JOIN) --
        ReadAuth = {
            param($Row, [bool]$IncludeSecrets)

            $method = if ($Row.PSObject.Properties['auth_method'] -and $Row.auth_method) { $Row.auth_method }
                      elseif ($Row.PSObject.Properties['Method']) { $Row.Method }
                      else { '' }

            $profileName = if ($Row.PSObject.Properties['auth_profile_name'] -and $Row.auth_profile_name) { $Row.auth_profile_name }
                           elseif ($Row.PSObject.Properties['ProfileName']) { $Row.ProfileName }
                           else { '' }

            $tenantId = if ($Row.PSObject.Properties['auth_tenant_id'] -and $Row.auth_tenant_id) { $Row.auth_tenant_id }
                        elseif ($Row.PSObject.Properties['TenantId']) { $Row.TenantId }
                        else { '' }

            $clientId = if ($Row.PSObject.Properties['auth_client_id'] -and $Row.auth_client_id) { $Row.auth_client_id }
                        elseif ($Row.PSObject.Properties['ClientId']) { $Row.ClientId }
                        else { '' }

            [PSCustomObject]@{
                Provider    = 'Azure'
                Enabled     = [bool]$method
                Method      = $method
                ProfileName = $profileName
                TenantId    = $tenantId
                ClientId    = $clientId
            }
        }

        # -- WriteAuth: Handle bool (enable/disable) only --
        # Full profile CRUD goes through *-CIEMAzureAuthenticationProfile functions
        WriteAuth = {
            param($Connection, [string]$ProviderId, $Auth, [string]$Timestamp)

            if ($Auth -is [bool]) {
                # Sync enabled flag only
                Invoke-PSUSQLiteQuery -Connection $Connection -Query "UPDATE azure_authentication_profiles SET is_active = @enabled, updated_at = @now WHERE provider_id = @id" -Parameters @{
                    id = $ProviderId; enabled = if ($Auth) { 1 } else { 0 }; now = $Timestamp
                } -AsNonQuery | Out-Null
            }
            else {
                # Full UPSERT via profile
                $method = if ($Auth.PSObject.Properties['Method']) { $Auth.Method } else { 'ServicePrincipalSecret' }
                $tenantId = if ($Auth.PSObject.Properties['TenantId']) { $Auth.TenantId } else { '' }
                $clientId = if ($Auth.PSObject.Properties['ClientId']) { $Auth.ClientId } else { $null }
                $managedIdentityClientId = if ($Auth.PSObject.Properties['ManagedIdentityClientId']) { $Auth.ManagedIdentityClientId } else { $null }

                # Determine profile-scoped secret naming
                $profileId = "$ProviderId-default"
                $secretName = $null
                $secretType = $null

                switch ($method) {
                    'ServicePrincipalSecret' {
                        $secretName = "CIEM_Azure_${profileId}_ClientSecret"
                        $secretType = 'ClientSecret'
                        # Migrate: if the auth object stored a secret via BuildAuth, it was already saved
                        # under the profile-scoped name. Also check for legacy name and copy if needed.
                        $legacySecret = Get-CIEMSecret 'CIEM_Azure_ClientSecret'
                        $profileSecret = Get-CIEMSecret $secretName
                        if ($legacySecret -and -not $profileSecret) {
                            Set-CIEMSecret $secretName $legacySecret
                            Write-CIEMLog -Message "Migrated ClientSecret from legacy name to $secretName" -Severity DEBUG -Component 'Azure-WriteAuth'
                        }
                    }
                    'ServicePrincipalCertificate' {
                        $secretName = "CIEM_Azure_${profileId}_CertThumbprint"
                        $secretType = 'CertThumbprint'
                        $legacySecret = Get-CIEMSecret 'CIEM_Azure_CertThumbprint'
                        $profileSecret = Get-CIEMSecret $secretName
                        if ($legacySecret -and -not $profileSecret) {
                            Set-CIEMSecret $secretName $legacySecret
                            Write-CIEMLog -Message "Migrated CertThumbprint from legacy name to $secretName" -Severity DEBUG -Component 'Azure-WriteAuth'
                        }
                    }
                }

                Invoke-PSUSQLiteQuery -Connection $Connection -Query @"
INSERT OR REPLACE INTO azure_authentication_profiles (id, provider_id, name, method, is_active, tenant_id, client_id, managed_identity_client_id, secret_name, secret_type, created_at, updated_at)
VALUES (@id, @provider_id, 'Default', @method, 1, @tenant_id, @client_id, @managed_identity_client_id, @secret_name, @secret_type, @now, @now)
"@ -Parameters @{
                    id                         = $profileId
                    provider_id                = $ProviderId
                    method                     = $method
                    tenant_id                  = $tenantId
                    client_id                  = $clientId
                    managed_identity_client_id = $managedIdentityClientId
                    secret_name                = $secretName
                    secret_type                = $secretType
                    now                        = $Timestamp
                } -AsNonQuery | Out-Null
            }
        }

        # -- TestAuth: Test Azure API connectivity via auth context --
        TestAuth = {
            param($Provider)

            $result = [PSCustomObject]@{
                Authenticated = $false
                Account       = $null
                TenantId      = $null
            }

            try {
                $ctx = $script:AzureAuthContext
                if ($ctx -and $ctx.IsConnected) {
                    $result.Account = $ctx.AccountId
                    $result.TenantId = $ctx.TenantId

                    $tokens = Get-CIEMToken
                    if ($tokens.GraphToken -and $tokens.ARMToken) {
                        $result.Authenticated = $true
                    }
                    elseif ($tokens.GraphToken -or $tokens.ARMToken) {
                        $graphApiBase = $Provider.Endpoints.graphApi
                        $armApiBase = $Provider.Endpoints.armApi

                        $graphOk = $false
                        try {
                            $graphResponse = Invoke-AzureApi -Uri "$graphApiBase/organization" -Api Graph -ResourceName 'Organization' -ErrorAction Stop
                            $graphOk = $null -ne $graphResponse
                        }
                        catch { Write-Verbose "Graph API test failed: $($_.Exception.Message)" }

                        $armOk = $false
                        try {
                            $armResponse = Invoke-AzureApi -Uri "$armApiBase/subscriptions?api-version=2020-01-01" -Api ARM -ResourceName 'Subscriptions' -ErrorAction Stop
                            $armOk = $null -ne $armResponse
                        }
                        catch { Write-Verbose "ARM API test failed: $($_.Exception.Message)" }

                        $result.Authenticated = $graphOk -and $armOk
                    }
                }
            }
            catch {
                Write-Verbose "Azure auth check failed: $($_.Exception.Message)"
            }

            $result
        }

        # -- BuildAuth: Build auth object and store profile-scoped secrets --
        BuildAuth = {
            param([hashtable]$Params)

            $profileId = "$(($Params.Provider ?? 'azure').ToLower())-default"

            $newAuth = [PSCustomObject]@{
                Provider                = 'Azure'
                Enabled                 = $true
                Method                  = $Params.Method
                TenantId                = $Params.TenantId
                ClientId                = $null
                ManagedIdentityClientId = $null
                ProfileId               = $profileId
            }

            switch ($Params.Method) {
                'ServicePrincipalSecret' {
                    $newAuth.ClientId = $Params.ClientId
                    if ($Params.ClientSecret) {
                        $secretName = "CIEM_Azure_${profileId}_ClientSecret"
                        Set-CIEMSecret $secretName $Params.ClientSecret
                        # Also save under legacy name for backward compatibility
                        Set-CIEMSecret 'CIEM_Azure_ClientSecret' $Params.ClientSecret
                        Write-CIEMLog -Message "Saved secret to $secretName (and legacy CIEM_Azure_ClientSecret)" -Severity DEBUG -Component 'Azure-BuildAuth'
                    }
                }
                'ServicePrincipalCertificate' {
                    $newAuth.ClientId = $Params.ClientId
                    if ($Params.CertThumbprint) {
                        $secretName = "CIEM_Azure_${profileId}_CertThumbprint"
                        Set-CIEMSecret $secretName $Params.CertThumbprint
                        Set-CIEMSecret 'CIEM_Azure_CertThumbprint' $Params.CertThumbprint
                        Write-CIEMLog -Message "Saved secret to $secretName (and legacy CIEM_Azure_CertThumbprint)" -Severity DEBUG -Component 'Azure-BuildAuth'
                    }
                }
                'ManagedIdentity' {
                    $newAuth.ManagedIdentityClientId = $Params.ManagedIdentityClientId
                }
            }

            $newAuth
        }

        # -- SeedDefaults: Seed Azure as default provider --
        SeedDefaults = {
            param($Connection, [string]$Timestamp)

            Invoke-PSUSQLiteQuery -Connection $Connection -Query "INSERT OR IGNORE INTO providers (id, name, type, enabled, is_default, created_at, updated_at) VALUES (@id, @name, @type, @enabled, @is_default, @now, @now)" -Parameters @{
                id = 'azure'; name = 'Azure'; type = 'Azure'; enabled = 1; is_default = 1; now = $Timestamp
            } -AsNonQuery | Out-Null
        }
    }

    Register-CIEMProviderType -Name 'Azure' -Callbacks $callbacks
}
