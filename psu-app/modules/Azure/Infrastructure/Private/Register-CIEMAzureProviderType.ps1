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

        # -- QueryAuth: No SQL join needed (auth profiles stored in PSU Variables) --
        QueryAuth = {
            @{ Columns = ''; JoinClause = '' }
        }

        # -- ReadAuth: Read active auth profile from PSU Variable --
        ReadAuth = {
            param($Row, [bool]$IncludeSecrets)

            $profile = @(Get-CIEMAzureAuthenticationProfile -ProviderId $Row.id -IsActive $true) | Select-Object -First 1

            [PSCustomObject]@{
                Provider    = 'Azure'
                Enabled     = [bool]$profile
                Method      = if ($profile) { $profile.Method } else { '' }
                ProfileName = if ($profile) { $profile.Name } else { '' }
                TenantId    = if ($profile) { $profile.TenantId } else { '' }
                ClientId    = if ($profile) { $profile.ClientId } else { '' }
            }
        }

        # -- WriteAuth: Persist auth profile via PSU Variable --
        WriteAuth = {
            param($Connection, [string]$ProviderId, $Auth, [string]$Timestamp)

            if ($Auth -is [bool]) {
                # Sync enabled flag on all profiles for this provider
                $profiles = @(Get-CIEMAzureAuthenticationProfile -ProviderId $ProviderId)
                foreach ($p in $profiles) {
                    Update-CIEMAzureAuthenticationProfile -Id $p.Id -IsActive $Auth
                }
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

                Save-CIEMAzureAuthenticationProfile -Id $profileId -ProviderId $ProviderId -Name 'Default' -Method $method -IsActive $true -TenantId $tenantId -ClientId $clientId -ManagedIdentityClientId $managedIdentityClientId -SecretName $secretName -SecretType $secretType
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
