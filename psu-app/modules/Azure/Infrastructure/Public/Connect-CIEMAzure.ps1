function Connect-CIEMAzure {
    <#
    .SYNOPSIS
        Establishes Azure authentication for CIEM scans.

    .DESCRIPTION
        Reads the active authentication profile, resolves credentials from PSU
        secrets, acquires ARM/Graph/KeyVault tokens, and populates the
        module-scoped AzureAuthContext.

        Supported methods: ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity.

    .PARAMETER AuthenticationProfile
        Optional. A pre-resolved CIEMAzureAuthenticationProfile object (with secrets).
        If not provided, the active profile is looked up automatically.

    .OUTPUTS
        [PSCustomObject] Auth context with TenantId, SubscriptionIds, AccountId, AccountType, ConnectedAt.

    .EXAMPLE
        $authContext = Connect-CIEMAzure
        $authContext.TenantId
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [CIEMAzureAuthenticationProfile]$AuthenticationProfile = (
            @(Get-CIEMAzureAuthenticationProfile -IsActive $true -ResolveSecrets) | Select-Object -First 1
        )
    )

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    Write-CIEMLog -Message "Connect-CIEMAzure started" -Severity INFO -Component 'Connect-CIEMAzure'

    # 1. Get provider for ResourceFilter/Endpoints
    $azureProvider = Get-CIEMProvider -Name 'Azure'
    if (-not $azureProvider) {
        throw "Azure provider not configured. Use New-CIEMProvider -Name 'Azure' to create it."
    }

    # 2. Validate the authentication profile
    $profile = $AuthenticationProfile
    if (-not $profile) {
        throw "No active Azure authentication profile found. Configure one on the Configuration page."
    }

    Write-CIEMLog -Message "Using profile '$($profile.Name)' (method: $($profile.Method))" -Severity INFO -Component 'Connect-CIEMAzure'

    # 3. Create auth context and populate from profile
    $ctx = [CIEMAzureAuthContext]::new()
    $ctx.ProfileId = $profile.Id
    $ctx.ProfileName = $profile.Name
    $ctx.ProviderId = $profile.ProviderId
    $ctx.Method = $profile.Method
    $ctx.TenantId = $profile.TenantId
    $ctx.ClientId = $profile.ClientId
    $ctx.ManagedIdentityClientId = $profile.ManagedIdentityClientId

    # Set module-scoped context early so token assignments work
    $script:AzureAuthContext = $ctx

    # Check if running in PSU context
    $inPSUContext = $null -ne (Get-Command -Name 'Get-PSUCache' -ErrorAction SilentlyContinue)
    Write-CIEMLog -Message "PSU context detected: $inPSUContext" -Severity INFO -Component 'Connect-CIEMAzure'

    # 4. Acquire tokens based on method
    switch ($profile.Method) {
        'ServicePrincipalSecret' {
            Write-CIEMLog -Message "Processing ServicePrincipalSecret authentication via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            Write-CIEMLog -Message "ClientSecret resolved: $(if($profile.ClientSecret){'yes'}else{'no'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            if (-not $profile.ClientId -or -not $profile.ClientSecret -or -not $profile.TenantId) {
                $ctx.LastError = "Missing credentials for ServicePrincipalSecret"
                throw @"
Authentication method is 'ServicePrincipalSecret' but credentials not found.

Credential sources:
  TenantId: Profile -> $($profile.TenantId) $(if($profile.TenantId){'[FOUND]'}else{'[MISSING]'})
  ClientId: Profile -> $($profile.ClientId) $(if($profile.ClientId){'[FOUND]'}else{'[MISSING]'})
  ClientSecret: Profile (resolved) $(if($profile.ClientSecret){'[FOUND]'}else{'[MISSING]'})

$(if (-not $inPSUContext) { "NOTE: Not running in PSU context - PSU secrets are not available." })
"@
            }

            $tokenUrl = "https://login.microsoftonline.com/$($profile.TenantId)/oauth2/v2.0/token"

            # Get ARM token via REST API
            Write-CIEMLog -Message "Requesting ARM token via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $armBody = @{
                client_id     = $profile.ClientId
                scope         = 'https://management.azure.com/.default'
                client_secret = $profile.ClientSecret
                grant_type    = 'client_credentials'
            }
            $armTokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $armBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            Write-CIEMLog -Message "ARM token obtained (expires in $($armTokenResponse.expires_in)s)" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get Graph token via REST API
            Write-CIEMLog -Message "Requesting Graph token via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $graphBody = @{
                client_id     = $profile.ClientId
                scope         = 'https://graph.microsoft.com/.default'
                client_secret = $profile.ClientSecret
                grant_type    = 'client_credentials'
            }
            $graphTokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $graphBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            Write-CIEMLog -Message "Graph token obtained (expires in $($graphTokenResponse.expires_in)s)" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get KeyVault token via REST API
            Write-CIEMLog -Message "Requesting KeyVault token via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $keyVaultBody = @{
                client_id     = $profile.ClientId
                scope         = 'https://vault.azure.net/.default'
                client_secret = $profile.ClientSecret
                grant_type    = 'client_credentials'
            }
            $keyVaultTokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $keyVaultBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            Write-CIEMLog -Message "KeyVault token obtained (expires in $($keyVaultTokenResponse.expires_in)s)" -Severity INFO -Component 'Connect-CIEMAzure'

            # Compute token expiry (earliest among the three)
            $expiresInSeconds = @($armTokenResponse.expires_in, $graphTokenResponse.expires_in, $keyVaultTokenResponse.expires_in) |
                Where-Object { $_ } | Sort-Object | Select-Object -First 1
            if ($expiresInSeconds) {
                $ctx.TokenExpiresAt = (Get-Date).AddSeconds([int]$expiresInSeconds)
            }

            # Store tokens directly on auth context
            $ctx.ARMToken = $armTokenResponse.access_token
            $ctx.GraphToken = $graphTokenResponse.access_token
            $ctx.KeyVaultToken = $keyVaultTokenResponse.access_token
            Write-CIEMLog -Message "Tokens stored on auth context" -Severity INFO -Component 'Connect-CIEMAzure'

            $ctx.AccountId = $profile.ClientId
            $ctx.AccountType = 'ServicePrincipal'
        }
        'ServicePrincipalCertificate' {
            Write-CIEMLog -Message "Processing ServicePrincipalCertificate authentication..." -Severity INFO -Component 'Connect-CIEMAzure'
            Write-CIEMLog -Message "Certificate resolved: $(if($profile.Certificate){'yes'}else{'no'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            if (-not $profile.ClientId -or -not $profile.TenantId) {
                $ctx.LastError = "Missing TenantId or ClientId for ServicePrincipalCertificate"
                throw "Authentication method is 'ServicePrincipalCertificate' but tenantId or clientId not found in profile"
            }

            if (-not $profile.Certificate) {
                $ctx.LastError = "PFX certificate not found or failed to load"
                throw "Certificate authentication requires a PFX certificate stored in PSU vault. Upload a PFX file on the Configuration page."
            }

            # Build client assertion JWT signed with certificate (replaces MSAL dependency)
            Write-CIEMLog -Message "Building client assertion JWT with certificate (thumbprint: $($profile.Certificate.Thumbprint))..." -Severity INFO -Component 'Connect-CIEMAzure'
            $cert = $profile.Certificate
            $tokenUrl = "https://login.microsoftonline.com/$($profile.TenantId)/oauth2/v2.0/token"

            # JWT header with x5t (base64url-encoded SHA-1 thumbprint)
            $thumbprintBytes = [byte[]]::new($cert.Thumbprint.Length / 2)
            for ($i = 0; $i -lt $thumbprintBytes.Length; $i++) {
                $thumbprintBytes[$i] = [Convert]::ToByte($cert.Thumbprint.Substring($i * 2, 2), 16)
            }
            $x5t = [Convert]::ToBase64String($thumbprintBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            $jwtHeader = @{ alg = 'RS256'; typ = 'JWT'; x5t = $x5t } | ConvertTo-Json -Compress
            $now = [DateTimeOffset]::UtcNow
            $jwtPayload = @{
                aud = $tokenUrl
                iss = $profile.ClientId
                sub = $profile.ClientId
                jti = [guid]::NewGuid().ToString()
                nbf = $now.ToUnixTimeSeconds()
                exp = $now.AddMinutes(10).ToUnixTimeSeconds()
            } | ConvertTo-Json -Compress

            # Base64url encode header and payload
            $toBase64Url = { param([string]$s) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
            $headerB64 = & $toBase64Url $jwtHeader
            $payloadB64 = & $toBase64Url $jwtPayload

            # Sign with RSA-SHA256 (use extension method via static call — PowerShell can't call extension methods directly)
            $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
            $sigBytes = $rsa.SignData([Text.Encoding]::UTF8.GetBytes("$headerB64.$payloadB64"), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
            $sigB64 = [Convert]::ToBase64String($sigBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            $clientAssertion = "$headerB64.$payloadB64.$sigB64"

            # Acquire tokens via REST using client_assertion
            $getTokenWithCert = {
                param([string]$Scope)
                $body = @{
                    client_id             = $profile.ClientId
                    scope                 = $Scope
                    client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
                    client_assertion      = $clientAssertion
                    grant_type            = 'client_credentials'
                }
                Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            }

            $armTokenResponse = & $getTokenWithCert -Scope 'https://management.azure.com/.default'
            $ctx.ARMToken = $armTokenResponse.access_token
            Write-CIEMLog -Message "ARM token acquired via certificate assertion" -Severity INFO -Component 'Connect-CIEMAzure'

            $graphTokenResponse = & $getTokenWithCert -Scope 'https://graph.microsoft.com/.default'
            $ctx.GraphToken = $graphTokenResponse.access_token
            Write-CIEMLog -Message "Graph token acquired via certificate assertion" -Severity INFO -Component 'Connect-CIEMAzure'

            $kvTokenResponse = & $getTokenWithCert -Scope 'https://vault.azure.net/.default'
            $ctx.KeyVaultToken = $kvTokenResponse.access_token
            Write-CIEMLog -Message "KeyVault token acquired via certificate assertion" -Severity INFO -Component 'Connect-CIEMAzure'

            # Compute token expiry (earliest among the three)
            $expiresInSeconds = @($armTokenResponse.expires_in, $graphTokenResponse.expires_in, $kvTokenResponse.expires_in) |
                Where-Object { $_ } | Sort-Object | Select-Object -First 1
            if ($expiresInSeconds) {
                $ctx.TokenExpiresAt = (Get-Date).AddSeconds([int]$expiresInSeconds)
            }

            Write-CIEMLog -Message "Certificate authentication completed successfully via REST" -Severity INFO -Component 'Connect-CIEMAzure'

            $ctx.AccountId = $profile.ClientId
            $ctx.AccountType = 'ServicePrincipal'
        }
        'ManagedIdentity' {
            Write-CIEMLog -Message "Processing ManagedIdentity authentication via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'

            $miClientId = $profile.ManagedIdentityClientId
            if ($miClientId) {
                Write-CIEMLog -Message "Using user-assigned managed identity: $miClientId" -Severity INFO -Component 'Connect-CIEMAzure'
            } else {
                Write-CIEMLog -Message "Using system-assigned managed identity" -Severity INFO -Component 'Connect-CIEMAzure'
            }

            # Azure App Service provides MSI endpoint via environment variables
            $identityEndpoint = $env:IDENTITY_ENDPOINT
            $identityHeader = $env:IDENTITY_HEADER

            if (-not $identityEndpoint -or -not $identityHeader) {
                $ctx.LastError = "MSI environment not detected"
                throw "Managed Identity environment not detected. IDENTITY_ENDPOINT and IDENTITY_HEADER must be set (Azure App Service MSI)."
            }

            Write-CIEMLog -Message "MSI endpoint detected: $identityEndpoint" -Severity DEBUG -Component 'Connect-CIEMAzure'

            # Helper to get token via MSI endpoint
            $getMsiToken = {
                param([string]$Resource)
                $tokenUri = "$identityEndpoint`?api-version=2019-08-01&resource=$Resource"
                if ($miClientId) {
                    $tokenUri += "&client_id=$miClientId"
                }
                $headers = @{ 'X-IDENTITY-HEADER' = $identityHeader }
                Invoke-RestMethod -Uri $tokenUri -Headers $headers -Method Get -ErrorAction Stop
            }

            # Get ARM token
            Write-CIEMLog -Message "Requesting ARM token via MSI REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $armTokenResponse = & $getMsiToken -Resource 'https://management.azure.com/'
            Write-CIEMLog -Message "ARM token obtained (expires: $($armTokenResponse.expires_on))" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get Graph token
            Write-CIEMLog -Message "Requesting Graph token via MSI REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $graphTokenResponse = & $getMsiToken -Resource 'https://graph.microsoft.com/'
            Write-CIEMLog -Message "Graph token obtained (expires: $($graphTokenResponse.expires_on))" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get KeyVault token
            Write-CIEMLog -Message "Requesting KeyVault token via MSI REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $keyVaultTokenResponse = & $getMsiToken -Resource 'https://vault.azure.net/'
            Write-CIEMLog -Message "KeyVault token obtained (expires: $($keyVaultTokenResponse.expires_on))" -Severity INFO -Component 'Connect-CIEMAzure'

            # Compute token expiry from expires_on (Unix timestamp)
            $expiresOn = @($armTokenResponse.expires_on, $graphTokenResponse.expires_on, $keyVaultTokenResponse.expires_on) |
                Where-Object { $_ } | Sort-Object | Select-Object -First 1
            if ($expiresOn) {
                $ctx.TokenExpiresAt = [DateTimeOffset]::FromUnixTimeSeconds([long]$expiresOn).LocalDateTime
            }

            # Store tokens directly on auth context
            $ctx.ARMToken = $armTokenResponse.access_token
            $ctx.GraphToken = $graphTokenResponse.access_token
            $ctx.KeyVaultToken = $keyVaultTokenResponse.access_token
            Write-CIEMLog -Message "Tokens stored on auth context" -Severity INFO -Component 'Connect-CIEMAzure'

            # Extract tenant ID and account ID from ARM token JWT payload
            $tokenParts = $armTokenResponse.access_token.Split('.')
            $payload = $tokenParts[1]
            $padLength = 4 - ($payload.Length % 4)
            if ($padLength -lt 4) { $payload += ('=' * $padLength) }
            $decodedPayload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
            $tokenClaims = $decodedPayload | ConvertFrom-Json
            $ctx.TenantId = $tokenClaims.tid
            $ctx.AccountId = $tokenClaims.oid
            $ctx.AccountType = 'ManagedIdentity'
            Write-CIEMLog -Message "Extracted from token - TenantId: $($ctx.TenantId), ObjectId: $($ctx.AccountId)" -Severity DEBUG -Component 'Connect-CIEMAzure'

            Write-CIEMLog -Message "Managed Identity authentication completed successfully" -Severity INFO -Component 'Connect-CIEMAzure'
        }
        default {
            $ctx.LastError = "Unknown authentication method: $($profile.Method)"
            throw "Unknown authentication method '$($profile.Method)'. Valid values: ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity"
        }
    }

    # List accessible subscriptions via ARM REST API
    Write-CIEMLog -Message "Getting accessible subscriptions via ARM REST API..." -Severity DEBUG -Component 'Connect-CIEMAzure'
    try {
        $subHeaders = @{ Authorization = "Bearer $($ctx.ARMToken)" }
        $subResponse = Invoke-RestMethod -Uri 'https://management.azure.com/subscriptions?api-version=2022-12-01' `
            -Headers $subHeaders -Method Get -ErrorAction Stop
        $subscriptions = @($subResponse.value | Where-Object { $_.state -eq 'Enabled' } | ForEach-Object {
            [PSCustomObject]@{ Id = $_.subscriptionId }
        })
    }
    catch {
        Write-CIEMLog -Message "ARM subscription listing failed: $($_.Exception.Message). Continuing with empty subscription list." -Severity WARNING -Component 'Connect-CIEMAzure'
        $subscriptions = @()
    }
    Write-CIEMLog -Message "Found $($subscriptions.Count) enabled subscriptions" -Severity DEBUG -Component 'Connect-CIEMAzure'

    # Filter to configured subscriptions if specified
    $subscriptionFilter = @($azureProvider.ResourceFilter)
    if ($subscriptionFilter -and $subscriptionFilter.Count -gt 0) {
        Write-CIEMLog -Message "Applying subscription filter: $($subscriptionFilter -join ', ')" -Severity DEBUG -Component 'Connect-CIEMAzure'
        $subscriptions = $subscriptions | Where-Object { $subscriptionFilter -contains $_.Id }
    }

    $subscriptionIds = @($subscriptions | Select-Object -ExpandProperty Id)

    if ($subscriptionIds.Count -eq 0) {
        Write-CIEMLog -Message "No accessible subscriptions found in tenant $($ctx.TenantId)" -Severity WARNING -Component 'Connect-CIEMAzure'
        Write-Warning "No accessible subscriptions found in tenant $($ctx.TenantId)"
    }
    else {
        Write-CIEMLog -Message "Accessible subscriptions: $($subscriptionIds.Count)" -Severity INFO -Component 'Connect-CIEMAzure'
    }

    # Finalize auth context
    $ctx.SubscriptionIds = $subscriptionIds
    $ctx.ConnectedAt = Get-Date
    $ctx.IsConnected = $true
    $ctx.LastError = $null

    Write-CIEMLog -Message "Connect-CIEMAzure completed successfully" -Severity INFO -Component 'Connect-CIEMAzure'

    # Return backward-compatible PSCustomObject
    [PSCustomObject]@{
        TenantId        = $ctx.TenantId
        SubscriptionIds = $ctx.SubscriptionIds
        AccountId       = $ctx.AccountId
        AccountType     = $ctx.AccountType
        ConnectedAt     = $ctx.ConnectedAt
    }
}
