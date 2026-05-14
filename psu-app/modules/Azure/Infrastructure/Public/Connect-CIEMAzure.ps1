function Connect-CIEMAzure {
    <#
    .SYNOPSIS
        Establishes Azure authentication for CIEM scans.

    .DESCRIPTION
        Reads the assigned generic authentication profile, resolves credentials
        from PSU secrets, acquires ARM/Graph/KeyVault tokens, and populates the
        module-scoped AzureAuthContext.

        Supported methods: ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity.

    .PARAMETER AuthenticationProfile
        Optional. A pre-resolved generic authentication profile object with
        secrets. If not provided, the Azure provider discovery assignment is
        resolved from Authentication Profiles.

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
        [object]$AuthenticationProfile
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
    $profile = if ($AuthenticationProfile) {
        $AuthenticationProfile
    }
    else {
        GetCIEMAssignedAuthenticationProfile -UsageType 'ProviderDiscovery' -UsageId 'Azure'
    }
    if ($profile.Provider -ne 'Azure') {
        throw "Authentication profile '$($profile.Id)' must have provider Azure."
    }

    Write-CIEMLog -Message "Using profile '$($profile.Name)' (method: $($profile.Method))" -Severity INFO -Component 'Connect-CIEMAzure'
    $settings = $profile.Settings
    $secrets = $profile.Secrets

    # 3. Create auth context and populate from profile
    $ctx = [CIEMAzureAuthContext]::new()
    $ctx.ProfileId = $profile.Id
    $ctx.ProfileName = $profile.Name
    $ctx.ProviderId = $azureProvider.Id
    $ctx.Method = $profile.Method
    $ctx.TenantId = $settings.TenantId
    $ctx.ClientId = $settings.ClientId
    $ctx.ManagedIdentityClientId = $settings.ManagedIdentityClientId

    # Set module-scoped context early so token assignments work
    $script:AzureAuthContext = $ctx

    # Check if running in PSU context
    $inPSUContext = $null -ne (Get-Command -Name 'Get-PSUCache' -ErrorAction SilentlyContinue)
    Write-CIEMLog -Message "PSU context detected: $inPSUContext" -Severity INFO -Component 'Connect-CIEMAzure'

    # 4. Token scopes — data drives which tokens to acquire
    # Adding a new API scope requires one row here + one property on CIEMAzureAuthContext
    $tokenScopes = @(
        @{ ApiName = 'ARM';      Resource = 'https://management.azure.com';  ContextProperty = 'ARMToken' }
        @{ ApiName = 'Graph';    Resource = 'https://graph.microsoft.com';   ContextProperty = 'GraphToken' }
        @{ ApiName = 'KeyVault'; Resource = 'https://vault.azure.net';       ContextProperty = 'KeyVaultToken' }
    )

    # 5. Acquire tokens based on method — each method builds a $getToken scriptblock,
    #    then the shared loop acquires tokens for all scopes
    $getToken = $null
    $expiryMode = 'expires_in'  # SP methods use expires_in (seconds); MSI uses expires_on (unix timestamp)

    switch ($profile.Method) {
        'ServicePrincipalSecret' {
            Write-CIEMLog -Message "Processing ServicePrincipalSecret authentication via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            Write-CIEMLog -Message "ClientSecret resolved: $(if($secrets.ClientSecret){'yes'}else{'no'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            if (-not $settings.ClientId -or -not $secrets.ClientSecret -or -not $settings.TenantId) {
                $ctx.LastError = "Missing credentials for ServicePrincipalSecret"
                throw @"
Authentication method is 'ServicePrincipalSecret' but credentials not found.

Credential sources:
  TenantId: Profile -> $($settings.TenantId) $(if($settings.TenantId){'[FOUND]'}else{'[MISSING]'})
  ClientId: Profile -> $($settings.ClientId) $(if($settings.ClientId){'[FOUND]'}else{'[MISSING]'})
  ClientSecret: Profile (resolved) $(if($secrets.ClientSecret){'[FOUND]'}else{'[MISSING]'})

$(if (-not $inPSUContext) { "NOTE: Not running in PSU context - PSU secrets are not available." })
"@
            }

            $tokenUrl = "https://login.microsoftonline.com/$($settings.TenantId)/oauth2/v2.0/token"

            $getToken = {
                param([string]$Scope)
                $body = @{
                    client_id     = $settings.ClientId
                    scope         = $Scope
                    client_secret = $secrets.ClientSecret
                    grant_type    = 'client_credentials'
                }
                Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            }

            $ctx.AccountId = $settings.ClientId
            $ctx.AccountType = 'ServicePrincipal'
        }
        'ServicePrincipalCertificate' {
            Write-CIEMLog -Message "Processing ServicePrincipalCertificate authentication..." -Severity INFO -Component 'Connect-CIEMAzure'
            Write-CIEMLog -Message "Certificate resolved: $(if($secrets.CertificatePfx){'yes'}else{'no'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            if (-not $settings.ClientId -or -not $settings.TenantId) {
                $ctx.LastError = "Missing TenantId or ClientId for ServicePrincipalCertificate"
                throw "Authentication method is 'ServicePrincipalCertificate' but tenantId or clientId not found in profile"
            }

            if (-not $secrets.CertificatePfx) {
                $ctx.LastError = "PFX certificate not found or failed to load"
                throw "Certificate authentication requires a PFX certificate stored in PSU vault. Upload a PFX file on the Authentication Profiles page."
            }

            $certificateBytes = [Convert]::FromBase64String([string]$secrets.CertificatePfx)
            $certificatePassword = $secrets.CertificatePassword
            $certificateStorageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificateBytes, $certificatePassword, $certificateStorageFlags)

            # Build client assertion JWT signed with certificate
            Write-CIEMLog -Message "Building client assertion JWT with certificate (thumbprint: $($cert.Thumbprint))..." -Severity INFO -Component 'Connect-CIEMAzure'
            $tokenUrl = "https://login.microsoftonline.com/$($settings.TenantId)/oauth2/v2.0/token"

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
                iss = $settings.ClientId
                sub = $settings.ClientId
                jti = [guid]::NewGuid().ToString()
                nbf = $now.ToUnixTimeSeconds()
                exp = $now.AddMinutes(10).ToUnixTimeSeconds()
            } | ConvertTo-Json -Compress

            # Base64url encode header and payload
            $toBase64Url = { param([string]$s) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
            $headerB64 = & $toBase64Url $jwtHeader
            $payloadB64 = & $toBase64Url $jwtPayload

            # Sign with RSA-SHA256
            $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
            $sigBytes = $rsa.SignData([Text.Encoding]::UTF8.GetBytes("$headerB64.$payloadB64"), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
            $sigB64 = [Convert]::ToBase64String($sigBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            $clientAssertion = "$headerB64.$payloadB64.$sigB64"

            $getToken = {
                param([string]$Scope)
                $body = @{
                    client_id             = $settings.ClientId
                    scope                 = $Scope
                    client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
                    client_assertion      = $clientAssertion
                    grant_type            = 'client_credentials'
                }
                Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            }

            $ctx.AccountId = $settings.ClientId
            $ctx.AccountType = 'ServicePrincipal'
        }
        'ManagedIdentity' {
            Write-CIEMLog -Message "Processing ManagedIdentity authentication via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'

            $miClientId = $settings.ManagedIdentityClientId
            if ($miClientId) {
                Write-CIEMLog -Message "Using user-assigned managed identity: $miClientId" -Severity INFO -Component 'Connect-CIEMAzure'
            } else {
                Write-CIEMLog -Message "Using system-assigned managed identity" -Severity INFO -Component 'Connect-CIEMAzure'
            }

            $identityEndpoint = $env:IDENTITY_ENDPOINT
            $identityHeader = $env:IDENTITY_HEADER

            if (-not $identityEndpoint -or -not $identityHeader) {
                $ctx.LastError = "MSI environment not detected"
                throw "Managed Identity environment not detected. IDENTITY_ENDPOINT and IDENTITY_HEADER must be set (Azure App Service MSI)."
            }

            Write-CIEMLog -Message "MSI endpoint detected: $identityEndpoint" -Severity DEBUG -Component 'Connect-CIEMAzure'

            $expiryMode = 'expires_on'

            $getToken = {
                param([string]$Scope)
                # MSI uses resource URL (no .default suffix) — Scope parameter is the resource URL
                $tokenUri = "$identityEndpoint`?api-version=2019-08-01&resource=$Scope"
                if ($miClientId) {
                    $tokenUri += "&client_id=$miClientId"
                }
                $headers = @{ 'X-IDENTITY-HEADER' = $identityHeader }
                Invoke-RestMethod -Uri $tokenUri -Headers $headers -Method Get -ErrorAction Stop
            }
        }
        default {
            $ctx.LastError = "Unknown authentication method: $($profile.Method)"
            throw "Unknown authentication method '$($profile.Method)'. Valid values: ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity"
        }
    }

    # 6. Shared token acquisition loop — driven by $tokenScopes data
    $tokenResponses = @{}
    $isMsi = $profile.Method -eq 'ManagedIdentity'

    foreach ($scope in $tokenScopes) {
        # SP methods use '.default' suffix; MSI uses trailing '/'
        $formattedScope = if ($isMsi) { "$($scope.Resource)/" } else { "$($scope.Resource)/.default" }

        Write-CIEMLog -Message "Requesting $($scope.ApiName) token..." -Severity INFO -Component 'Connect-CIEMAzure'
        $response = & $getToken -Scope $formattedScope
        $tokenResponses[$scope.ApiName] = $response
        $ctx.($scope.ContextProperty) = $response.access_token
        Write-CIEMLog -Message "$($scope.ApiName) token acquired" -Severity INFO -Component 'Connect-CIEMAzure'
    }

    # 7. Shared expiry computation
    if ($expiryMode -eq 'expires_in') {
        $expiresInSeconds = @($tokenResponses.Values | ForEach-Object { $_.expires_in }) |
            Where-Object { $_ } | Sort-Object | Select-Object -First 1
        if ($expiresInSeconds) {
            $ctx.TokenExpiresAt = (Get-Date).AddSeconds([int]$expiresInSeconds)
        }
    } else {
        $expiresOn = @($tokenResponses.Values | ForEach-Object { $_.expires_on }) |
            Where-Object { $_ } | Sort-Object | Select-Object -First 1
        if ($expiresOn) {
            $ctx.TokenExpiresAt = [DateTimeOffset]::FromUnixTimeSeconds([long]$expiresOn).LocalDateTime
        }
    }

    Write-CIEMLog -Message "Tokens stored on auth context" -Severity INFO -Component 'Connect-CIEMAzure'

    # 8. ManagedIdentity post-processing: extract tenant/account from ARM JWT
    if ($isMsi) {
        $tokenParts = $tokenResponses['ARM'].access_token.Split('.')
        $payload = $tokenParts[1]
        $padLength = 4 - ($payload.Length % 4)
        if ($padLength -lt 4) { $payload += ('=' * $padLength) }
        $decodedPayload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
        $tokenClaims = $decodedPayload | ConvertFrom-Json
        $ctx.TenantId = $tokenClaims.tid
        $ctx.AccountId = $tokenClaims.oid
        $ctx.AccountType = 'ManagedIdentity'
        Write-CIEMLog -Message "Extracted from token - TenantId: $($ctx.TenantId), ObjectId: $($ctx.AccountId)" -Severity DEBUG -Component 'Connect-CIEMAzure'
    }

    # List accessible subscriptions via ARM REST API
    Write-CIEMLog -Message "Getting accessible subscriptions via ARM REST API..." -Severity DEBUG -Component 'Connect-CIEMAzure'
    $subHeaders = @{ Authorization = "Bearer $($ctx.ARMToken)" }
    $subResponse = Invoke-RestMethod -Uri 'https://management.azure.com/subscriptions?api-version=2022-12-01' `
        -Headers $subHeaders -Method Get -ErrorAction Stop
    $subscriptions = @($subResponse.value | Where-Object { $_.state -eq 'Enabled' } | ForEach-Object {
        [PSCustomObject]@{ Id = $_.subscriptionId }
    })
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
