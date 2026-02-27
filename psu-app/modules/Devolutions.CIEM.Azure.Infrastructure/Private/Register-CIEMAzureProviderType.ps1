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

        # ── Default API endpoints ──────────────────────────────────────
        DefaultEndpoints = {
            [PSCustomObject]@{
                graphApi = 'https://graph.microsoft.com/v1.0'
                armApi   = 'https://management.azure.com'
            }
        }

        # ── QueryAuth: SQL fragments for azure_authentication_profiles ─
        QueryAuth = {
            @{
                Columns    = 'a.id AS auth_id, a.name AS auth_name, a.method AS auth_method, a.is_active AS auth_enabled, a.tenant_id, a.client_id, a.managed_identity_client_id, a.secret_name, a.secret_type'
                JoinClause = 'LEFT JOIN azure_authentication_profiles a ON a.provider_id = p.id AND a.is_active = 1'
            }
        }

        # ── ReadAuth: Reconstruct auth PSCustomObject from DB row ──────
        ReadAuth = {
            param($Row, [bool]$IncludeSecrets)

            # Handle both DB rows (auth_method) and raw auth objects (Method)
            $method = if ($Row.PSObject.Properties['auth_method'] -and $Row.auth_method) { $Row.auth_method }
                      elseif ($Row.PSObject.Properties['Method']) { $Row.Method }
                      else { 'ServicePrincipalSecret' }

            $enabled = if ($null -ne $Row.PSObject.Properties['auth_enabled'] -and $null -ne $Row.auth_enabled) { [bool]$Row.auth_enabled }
                       elseif ($Row.PSObject.Properties['Enabled']) { [bool]$Row.Enabled }
                       elseif ($Row.PSObject.Properties['enabled']) { [bool]$Row.enabled }
                       else { $false }

            $tenantId = if ($Row.PSObject.Properties['tenant_id']) { $Row.tenant_id }
                        elseif ($Row.PSObject.Properties['TenantId']) { $Row.TenantId }
                        else { '' }

            $clientId = if ($Row.PSObject.Properties['client_id']) { $Row.client_id }
                        elseif ($Row.PSObject.Properties['ClientId']) { $Row.ClientId }
                        else { $null }

            $miClientId = if ($Row.PSObject.Properties['managed_identity_client_id']) { $Row.managed_identity_client_id }
                          elseif ($Row.PSObject.Properties['ManagedIdentityClientId']) { $Row.ManagedIdentityClientId }
                          else { $null }

            $auth = [PSCustomObject]@{
                Provider                = 'Azure'
                Enabled                 = $enabled
                Method                  = $method
                TenantId                = $tenantId
                ClientId                = $clientId
                ManagedIdentityClientId = $miClientId
            }

            if ($IncludeSecrets) {
                switch ($method) {
                    'ServicePrincipalSecret' {
                        $auth | Add-Member -NotePropertyName 'HasClientSecret' -NotePropertyValue ([bool](Get-CIEMSecret 'CIEM_Azure_ClientSecret'))
                    }
                    'ServicePrincipalCertificate' {
                        $auth | Add-Member -NotePropertyName 'HasCertThumbprint' -NotePropertyValue ([bool](Get-CIEMSecret 'CIEM_Azure_CertThumbprint'))
                    }
                }
            }

            $auth
        }

        # ── WriteAuth: Persist auth to azure_authentication_profiles ───
        WriteAuth = {
            param($Connection, [string]$ProviderId, $Auth, [string]$Timestamp)

            if ($Auth -is [bool]) {
                # Sync enabled flag only
                Invoke-PSUSQLiteQuery -Connection $Connection -Query "UPDATE azure_authentication_profiles SET is_active = @enabled, updated_at = @now WHERE provider_id = @id" -Parameters @{
                    id = $ProviderId; enabled = if ($Auth) { 1 } else { 0 }; now = $Timestamp
                } -AsNonQuery | Out-Null
            }
            else {
                # Full UPSERT
                $method = if ($Auth.PSObject.Properties['Method']) { $Auth.Method } else { 'ServicePrincipalSecret' }
                $tenantId = if ($Auth.PSObject.Properties['TenantId']) { $Auth.TenantId } else { '' }
                $clientId = if ($Auth.PSObject.Properties['ClientId']) { $Auth.ClientId } else { $null }
                $managedIdentityClientId = if ($Auth.PSObject.Properties['ManagedIdentityClientId']) { $Auth.ManagedIdentityClientId } else { $null }

                Invoke-PSUSQLiteQuery -Connection $Connection -Query @"
INSERT OR REPLACE INTO azure_authentication_profiles (id, provider_id, name, method, is_active, tenant_id, client_id, managed_identity_client_id, created_at, updated_at)
VALUES (@id, @provider_id, 'Default', @method, 1, @tenant_id, @client_id, @managed_identity_client_id, @now, @now)
"@ -Parameters @{
                    id                         = "$ProviderId-default"
                    provider_id                = $ProviderId
                    method                     = $method
                    tenant_id                  = $tenantId
                    client_id                  = $clientId
                    managed_identity_client_id = $managedIdentityClientId
                    now                        = $Timestamp
                } -AsNonQuery | Out-Null
            }
        }

        # ── TestAuth: Test Azure API connectivity ──────────────────────
        TestAuth = {
            param($Provider)

            $result = [PSCustomObject]@{
                Authenticated = $false
                Account       = $null
                TenantId      = $null
            }

            try {
                $context = Get-AzContext -ErrorAction SilentlyContinue
                if ($context -and $context.Account) {
                    $result.Account = $context.Account.Id
                    $result.TenantId = $context.Tenant.Id

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

        # ── BuildAuth: Build auth object from user params ──────────────
        BuildAuth = {
            param([hashtable]$Params)

            $newAuth = [PSCustomObject]@{
                Provider                = 'Azure'
                Enabled                 = $true
                Method                  = $Params.Method
                TenantId                = $Params.TenantId
                ClientId                = $null
                ManagedIdentityClientId = $null
            }

            switch ($Params.Method) {
                'ServicePrincipalSecret' {
                    $newAuth.ClientId = $Params.ClientId
                    if ($Params.ClientSecret) {
                        Set-CIEMSecret 'CIEM_Azure_ClientSecret' $Params.ClientSecret
                        Write-CIEMLog -Message "Saved CIEM_Azure_ClientSecret to PSU secrets" -Severity DEBUG -Component 'Azure-BuildAuth'
                    }
                }
                'ServicePrincipalCertificate' {
                    $newAuth.ClientId = $Params.ClientId
                    if ($Params.CertThumbprint) {
                        Set-CIEMSecret 'CIEM_Azure_CertThumbprint' $Params.CertThumbprint
                        Write-CIEMLog -Message "Saved CIEM_Azure_CertThumbprint to PSU secrets" -Severity DEBUG -Component 'Azure-BuildAuth'
                    }
                }
                'ManagedIdentity' {
                    $newAuth.ManagedIdentityClientId = $Params.ManagedIdentityClientId
                }
            }

            $newAuth
        }

        # ── SeedDefaults: Seed Azure as default provider ───────────────
        SeedDefaults = {
            param($Connection, [string]$Timestamp)

            Invoke-PSUSQLiteQuery -Connection $Connection -Query "INSERT OR IGNORE INTO providers (id, name, type, enabled, is_default, created_at, updated_at) VALUES (@id, @name, @type, @enabled, @is_default, @now, @now)" -Parameters @{
                id = 'azure'; name = 'Azure'; type = 'Azure'; enabled = 1; is_default = 1; now = $Timestamp
            } -AsNonQuery | Out-Null

            Invoke-PSUSQLiteQuery -Connection $Connection -Query "INSERT OR IGNORE INTO azure_authentication_profiles (id, provider_id, name, method, is_active, tenant_id, created_at, updated_at) VALUES (@id, @provider_id, @name, @method, @is_active, @tenant_id, @now, @now)" -Parameters @{
                id = 'azure-default'; provider_id = 'azure'; name = 'Default'; method = 'ServicePrincipalSecret'; is_active = 1; tenant_id = ''; now = $Timestamp
            } -AsNonQuery | Out-Null
        }
    }

    Register-CIEMProviderType -Name 'Azure' -Callbacks $callbacks
}
