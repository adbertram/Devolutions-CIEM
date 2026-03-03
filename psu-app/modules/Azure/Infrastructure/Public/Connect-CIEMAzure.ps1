function Connect-CIEMAzure {
    <#
    .SYNOPSIS
        Establishes Azure authentication for CIEM scans.

    .DESCRIPTION
        Queries the active authentication profile directly from the database,
        resolves credentials from PSU secrets, acquires ARM/Graph/KeyVault tokens,
        and populates the module-scoped AzureAuthContext.

        Supported methods: ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity.

    .OUTPUTS
        [PSCustomObject] Auth context with TenantId, SubscriptionIds, AccountId, AccountType, ConnectedAt.

    .EXAMPLE
        $authContext = Connect-CIEMAzure
        $authContext.TenantId
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    Write-CIEMLog -Message "Connect-CIEMAzure started" -Severity INFO -Component 'Connect-CIEMAzure'

    # Clear any existing Az context to ensure clean authentication
    Write-CIEMLog -Message "Clearing existing Az context..." -Severity DEBUG -Component 'Connect-CIEMAzure'
    Clear-AzContext -Force -ErrorAction SilentlyContinue | Out-Null

    # 1. Get provider for ResourceFilter/Endpoints
    $azureProvider = Get-CIEMProvider -Name 'Azure'
    if (-not $azureProvider) {
        throw "Azure provider not configured. Use New-CIEMProvider -Name 'Azure' to create it."
    }

    # 2. Query active profile directly
    $profile = @(Get-CIEMAzureAuthenticationProfile -ProviderId 'azure' -IsActive $true)
    if (-not $profile -or $profile.Count -eq 0) {
        throw "No active Azure authentication profile found. Use Save-CIEMAuthenticationContext to configure one."
    }
    $profile = $profile[0]  # Use the first active profile

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

    # Set module-scoped context early so Save-CIEMToken can write into it
    $script:AzureAuthContext = $ctx

    # Check if running in PSU context (Secret: drive available)
    $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
    Write-CIEMLog -Message "PSU context detected: $inPSUContext" -Severity INFO -Component 'Connect-CIEMAzure'

    # 4. Acquire tokens based on method
    switch ($profile.Method) {
        'ServicePrincipalSecret' {
            Write-CIEMLog -Message "Processing ServicePrincipalSecret authentication via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'

            # Look up secret using profile's SecretName, fall back to legacy name
            $secretName = if ($profile.SecretName) { $profile.SecretName } else { 'CIEM_Azure_ClientSecret' }
            $clientSecret = Get-CIEMSecret $secretName
            Write-CIEMLog -Message "Secret '$secretName': $(if($clientSecret){'found'}else{'null'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            if (-not $profile.ClientId -or -not $clientSecret -or -not $profile.TenantId) {
                $ctx.LastError = "Missing credentials for ServicePrincipalSecret"
                throw @"
Authentication method is 'ServicePrincipalSecret' but credentials not found.

Credential sources:
  TenantId: Profile -> $($profile.TenantId) $(if($profile.TenantId){'[FOUND]'}else{'[MISSING]'})
  ClientId: Profile -> $($profile.ClientId) $(if($profile.ClientId){'[FOUND]'}else{'[MISSING]'})
  ClientSecret: PSU secret -> $secretName $(if($clientSecret){'[FOUND]'}else{'[MISSING]'})

$(if (-not $inPSUContext) { "NOTE: Not running in PSU context - PSU secrets are not available." })
"@
            }

            $tokenUrl = "https://login.microsoftonline.com/$($profile.TenantId)/oauth2/v2.0/token"

            # Get ARM token via REST API
            Write-CIEMLog -Message "Requesting ARM token via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $armBody = @{
                client_id     = $profile.ClientId
                scope         = 'https://management.azure.com/.default'
                client_secret = $clientSecret
                grant_type    = 'client_credentials'
            }
            $armTokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $armBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            Write-CIEMLog -Message "ARM token obtained (expires in $($armTokenResponse.expires_in)s)" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get Graph token via REST API
            Write-CIEMLog -Message "Requesting Graph token via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $graphBody = @{
                client_id     = $profile.ClientId
                scope         = 'https://graph.microsoft.com/.default'
                client_secret = $clientSecret
                grant_type    = 'client_credentials'
            }
            $graphTokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $graphBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            Write-CIEMLog -Message "Graph token obtained (expires in $($graphTokenResponse.expires_in)s)" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get KeyVault token via REST API
            Write-CIEMLog -Message "Requesting KeyVault token via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $keyVaultBody = @{
                client_id     = $profile.ClientId
                scope         = 'https://vault.azure.net/.default'
                client_secret = $clientSecret
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

            # Store tokens
            Save-CIEMToken -ARMToken $armTokenResponse.access_token -GraphToken $graphTokenResponse.access_token -KeyVaultToken $keyVaultTokenResponse.access_token
            Write-CIEMLog -Message "Tokens saved" -Severity INFO -Component 'Connect-CIEMAzure'

            # Inject ARM token into Az context
            Write-CIEMLog -Message "Injecting ARM token into Az context via Connect-AzAccount -AccessToken..." -Severity INFO -Component 'Connect-CIEMAzure'
            Connect-AzAccount -AccessToken $armTokenResponse.access_token -AccountId $profile.ClientId -TenantId $profile.TenantId -ErrorAction Stop | Out-Null
            Write-CIEMLog -Message "Az context established successfully" -Severity INFO -Component 'Connect-CIEMAzure'

            $ctx.AccountId = $profile.ClientId
            $ctx.AccountType = 'ServicePrincipal'
        }
        'ServicePrincipalCertificate' {
            Write-CIEMLog -Message "Processing ServicePrincipalCertificate authentication..." -Severity INFO -Component 'Connect-CIEMAzure'

            # Look up thumbprint using profile's SecretName, fall back to legacy name
            $secretName = if ($profile.SecretName) { $profile.SecretName } else { 'CIEM_Azure_CertThumbprint' }
            $thumbprint = Get-CIEMSecret $secretName
            Write-CIEMLog -Message "Secret '$secretName': $(if($thumbprint){'found'}else{'null'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            if (-not $profile.ClientId -or -not $profile.TenantId) {
                $ctx.LastError = "Missing TenantId or ClientId for ServicePrincipalCertificate"
                throw "Authentication method is 'ServicePrincipalCertificate' but tenantId or clientId not found in profile"
            }

            if (-not $thumbprint) {
                $ctx.LastError = "Certificate thumbprint not found"
                throw "Certificate authentication requires thumbprint in PSU secret ($secretName)"
            }

            $connectParams = @{
                ServicePrincipal      = $true
                ApplicationId         = $profile.ClientId
                TenantId              = $profile.TenantId
                CertificateThumbprint = $thumbprint
            }

            Write-CIEMLog -Message "Calling Connect-AzAccount with certificate..." -Severity INFO -Component 'Connect-CIEMAzure'
            Connect-AzAccount @connectParams -ErrorAction Stop | Out-Null
            Write-CIEMLog -Message "Certificate authentication completed successfully" -Severity INFO -Component 'Connect-CIEMAzure'

            # Acquire Graph token using Get-AzAccessToken
            Write-CIEMLog -Message "Acquiring Graph token via Get-AzAccessToken..." -Severity INFO -Component 'Connect-CIEMAzure'
            $graphTokenResponse = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -ErrorAction Stop
            Save-CIEMToken -GraphToken $graphTokenResponse.Token
            Write-CIEMLog -Message "Graph token saved" -Severity INFO -Component 'Connect-CIEMAzure'

            # Acquire KeyVault token using Get-AzAccessToken
            Write-CIEMLog -Message "Acquiring KeyVault token via Get-AzAccessToken..." -Severity INFO -Component 'Connect-CIEMAzure'
            $kvTokenResponse = Get-AzAccessToken -ResourceUrl "https://vault.azure.net" -ErrorAction Stop
            Save-CIEMToken -KeyVaultToken $kvTokenResponse.Token
            Write-CIEMLog -Message "KeyVault token saved" -Severity INFO -Component 'Connect-CIEMAzure'

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

            # Store tokens
            Save-CIEMToken -ARMToken $armTokenResponse.access_token -GraphToken $graphTokenResponse.access_token -KeyVaultToken $keyVaultTokenResponse.access_token
            Write-CIEMLog -Message "Tokens saved" -Severity INFO -Component 'Connect-CIEMAzure'

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

            # Inject ARM token into Az context
            Write-CIEMLog -Message "Injecting ARM token into Az context via Connect-AzAccount -AccessToken..." -Severity INFO -Component 'Connect-CIEMAzure'
            Connect-AzAccount -AccessToken $armTokenResponse.access_token -AccountId $ctx.AccountId -TenantId $ctx.TenantId -ErrorAction Stop | Out-Null
            Write-CIEMLog -Message "Az context established successfully via Managed Identity" -Severity INFO -Component 'Connect-CIEMAzure'
        }
        default {
            $ctx.LastError = "Unknown authentication method: $($profile.Method)"
            throw "Unknown authentication method '$($profile.Method)'. Valid values: ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity"
        }
    }

    # Get Azure context with retry logic for PSU runspace stability
    Write-CIEMLog -Message "Getting Azure context..." -Severity DEBUG -Component 'Connect-CIEMAzure'
    $context = $null
    $retryCount = 0
    $maxRetries = 2

    while (-not $context -and $retryCount -lt $maxRetries) {
        try {
            $context = Get-AzContext -ErrorAction Stop
            if (-not $context -or -not $context.Account) {
                throw "Az context is empty or invalid"
            }
        }
        catch {
            $retryCount++
            Write-CIEMLog -Message "Get-AzContext attempt $retryCount failed: $($_.Exception.Message)" -Severity WARNING -Component 'Connect-CIEMAzure'
            if ($retryCount -lt $maxRetries) {
                Clear-AzContext -Force -ErrorAction SilentlyContinue | Out-Null
                Start-Sleep -Milliseconds 500
            }
            else {
                $ctx.LastError = "Failed to get valid Az context after $maxRetries attempts"
                throw "Failed to get valid Az context after $maxRetries attempts: $($_.Exception.Message)"
            }
        }
    }
    Write-CIEMLog -Message "Azure context obtained: Account=$($context.Account.Id), Tenant=$($context.Tenant.Id)" -Severity INFO -Component 'Connect-CIEMAzure'

    # Get all accessible subscriptions with error handling
    Write-CIEMLog -Message "Getting accessible subscriptions..." -Severity DEBUG -Component 'Connect-CIEMAzure'
    try {
        $subscriptions = @(Get-AzSubscription -TenantId $context.Tenant.Id -ErrorAction Stop)
    }
    catch {
        Write-CIEMLog -Message "Get-AzSubscription failed: $($_.Exception.Message). Continuing with empty subscription list." -Severity WARNING -Component 'Connect-CIEMAzure'
        $subscriptions = @()
    }
    Write-CIEMLog -Message "Found $($subscriptions.Count) subscriptions" -Severity DEBUG -Component 'Connect-CIEMAzure'

    # Filter to configured subscriptions if specified
    $subscriptionFilter = @($azureProvider.ResourceFilter)
    if ($subscriptionFilter -and $subscriptionFilter.Count -gt 0) {
        Write-CIEMLog -Message "Applying subscription filter: $($subscriptionFilter -join ', ')" -Severity DEBUG -Component 'Connect-CIEMAzure'
        $subscriptions = $subscriptions | Where-Object { $subscriptionFilter -contains $_.Id }
    }

    $subscriptionIds = @($subscriptions | Select-Object -ExpandProperty Id)

    if ($subscriptionIds.Count -eq 0) {
        Write-CIEMLog -Message "No accessible subscriptions found in tenant $($context.Tenant.Id)" -Severity WARNING -Component 'Connect-CIEMAzure'
        Write-Warning "No accessible subscriptions found in tenant $($context.Tenant.Id)"
    }
    else {
        Write-CIEMLog -Message "Accessible subscriptions: $($subscriptionIds.Count)" -Severity INFO -Component 'Connect-CIEMAzure'
    }

    # Finalize auth context
    $ctx.SubscriptionIds = $subscriptionIds
    if (-not $ctx.TenantId) { $ctx.TenantId = $context.Tenant.Id }
    $ctx.ConnectedAt = Get-Date
    $ctx.IsConnected = $true
    $ctx.LastError = $null

    # Determine account type from Az context if not already set
    if (-not $ctx.AccountType) {
        $ctx.AccountType = switch ($context.Account.Type) {
            'User' { 'User' }
            'ServicePrincipal' { 'ServicePrincipal' }
            'ManagedService' { 'ManagedIdentity' }
            default { $context.Account.Type }
        }
    }

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
