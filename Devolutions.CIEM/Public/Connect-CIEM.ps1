function Connect-CIEM {
    <#
    .SYNOPSIS
        Establishes authentication to all configured cloud providers for CIEM scans.

    .DESCRIPTION
        Reads authentication configuration from PSU cache and connects to each
        enabled cloud provider. This function must be called once before running
        any CIEM scans. The connection is cached for the duration of the PowerShell
        session.

        Currently supports:
        - Azure (ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity, Interactive)
        - AWS (coming soon)

    .PARAMETER Provider
        Optional. Connect only to specific provider(s). If not specified, connects
        to the provider defined in the CIEM config's cloudProvider setting.

    .PARAMETER Force
        Force re-authentication even if already connected.

    .OUTPUTS
        [PSCustomObject] Connection summary showing status for each provider.

    .EXAMPLE
        Connect-CIEM
        # Connects to the default provider from CIEM config

    .EXAMPLE
        Connect-CIEM -Provider Azure
        # Connects only to Azure

    .EXAMPLE
        Connect-CIEM -Force
        # Forces re-authentication even if already connected

    .NOTES
        This function must be called before running Invoke-CIEMScan or any other
        scan functions. Use Test-CIEMAuthenticated to check connection status.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [CIEMCloudProvider[]]$Provider,

        [Parameter()]
        [switch]$Force
    )

    $ErrorActionPreference = 'Stop'

    Write-CIEMLog -Message "Connect-CIEM called with Provider=[$($Provider -join ',')] Force=$Force" -Severity INFO -Component 'Connect-CIEM'

    # Initialize auth context storage if not exists
    if (-not $script:AuthContext) {
        $script:AuthContext = @{}
        Write-CIEMLog -Message "Initialized empty AuthContext" -Severity DEBUG -Component 'Connect-CIEM'
    }

    # Determine which providers to connect
    if (-not $Provider) {
        $Provider = @($script:Config.cloudProvider)
        Write-CIEMLog -Message "No provider specified, using config default: $($script:Config.cloudProvider)" -Severity DEBUG -Component 'Connect-CIEM'
    }

    Write-CIEMLog -Message "Providers to connect: $($Provider -join ', ')" -Severity INFO -Component 'Connect-CIEM'

    # Use List for efficient collection (summary returned at end)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($p in $Provider) {
        Write-CIEMLog -Message "Processing provider: $p" -Severity INFO -Component 'Connect-CIEM'
        Write-Verbose "Connecting to provider: $p"

        # Skip if already connected and not forcing
        if (-not $Force.IsPresent -and $script:AuthContext[$p]) {
            Write-CIEMLog -Message "$p is already connected (AccountId: $($script:AuthContext[$p].AccountId)). Skipping." -Severity INFO -Component 'Connect-CIEM'
            Write-Verbose "$p is already connected. Use -Force to re-authenticate."
            $results.Add([PSCustomObject]@{
                Provider = $p
                Status   = 'AlreadyConnected'
                Account  = $script:AuthContext[$p].AccountId
                TenantId = $script:AuthContext[$p].TenantId
                Message  = 'Already authenticated. Use -Force to re-authenticate.'
            })
            continue
        }

        try {
            switch ($p) {
                'Azure' {
                    Write-CIEMLog -Message "Calling Connect-CIEMAzure..." -Severity INFO -Component 'Connect-CIEM'
                    $authContext = Connect-CIEMAzure
                    $script:AuthContext['Azure'] = $authContext
                    Write-CIEMLog -Message "Azure connection successful. AccountId: $($authContext.AccountId), TenantId: $($authContext.TenantId), Subscriptions: $(@($authContext.SubscriptionIds).Count)" -Severity INFO -Component 'Connect-CIEM'

                    $results.Add([PSCustomObject]@{
                        Provider      = 'Azure'
                        Status        = 'Connected'
                        Account       = $authContext.AccountId
                        TenantId      = $authContext.TenantId
                        Subscriptions = @($authContext.SubscriptionIds).Count
                        Message       = "Connected as $($authContext.AccountType)"
                    })
                }
                'AWS' {
                    Write-CIEMLog -Message "Calling Connect-CIEMAWS..." -Severity INFO -Component 'Connect-CIEM'
                    $authContext = Connect-CIEMAWS
                    $script:AuthContext['AWS'] = $authContext
                    Write-CIEMLog -Message "AWS connection successful. AccountId: $($authContext.AccountId), Arn: $($authContext.Arn), Region: $($authContext.Region)" -Severity INFO -Component 'Connect-CIEM'

                    $results.Add([PSCustomObject]@{
                        Provider = 'AWS'
                        Status   = 'Connected'
                        Account  = $authContext.AccountId
                        TenantId = $null
                        Message  = "Connected as $($authContext.AccountType) ($($authContext.Arn))"
                    })
                }
            }
        }
        catch {
            $script:AuthContext[$p] = $null
            Write-CIEMLog -Message "Failed to connect to $p : $($_.Exception.Message)" -Severity ERROR -Component 'Connect-CIEM'
            Write-CIEMLog -Message "Stack trace: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'Connect-CIEM'
            $results.Add([PSCustomObject]@{
                Provider = $p
                Status   = 'Failed'
                Account  = $null
                TenantId = $null
                Message  = $_.Exception.Message
            })
            Write-Error "Failed to connect to $p : $_"
        }
    }

    # Display summary using Write-Information for proper pipeline behavior
    Write-Information "`nCIEM Connection Summary:" -InformationAction Continue
    foreach ($r in $results) {
        $statusDisplay = "  $($r.Provider): $($r.Status)"
        if ($r.Account) {
            $statusDisplay += " ($($r.Account))"
        }
        Write-Information $statusDisplay -InformationAction Continue
    }

    Write-CIEMLog -Message "Connect-CIEM completed. Results: $(($results | ForEach-Object { "$($_.Provider)=$($_.Status)" }) -join ', ')" -Severity INFO -Component 'Connect-CIEM'

    [PSCustomObject]@{
        Providers = $results
        Timestamp = Get-Date
    }
}

function Connect-CIEMAzure {
    <#
    .SYNOPSIS
        Internal function to establish Azure authentication.

    .DESCRIPTION
        Uses REST API to obtain OAuth tokens, then injects them into Az context
        via Connect-AzAccount -AccessToken. This avoids MSAL library issues on Linux.

        Credential sources:
        - TenantId, ClientId: PSU cache (azure.authentication.tenantId, azure.authentication.servicePrincipal.clientId)
        - ClientSecret: PSU secret (CIEM_Azure_ClientSecret)
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $ErrorActionPreference = 'Stop'

    Write-CIEMLog -Message "Connect-CIEMAzure started" -Severity INFO -Component 'Connect-CIEMAzure'

    # Clear any existing Az context to ensure clean authentication
    Write-CIEMLog -Message "Clearing existing Az context..." -Severity DEBUG -Component 'Connect-CIEMAzure'
    Clear-AzContext -Force -ErrorAction SilentlyContinue | Out-Null

    # Note: $script:Config should be updated by Save-CIEMConfig before calling Connect-CIEM
    if (-not $script:Config) {
        Write-CIEMLog -Message "Config not loaded, calling Get-CIEMConfig..." -Severity DEBUG -Component 'Connect-CIEMAzure'
        $script:Config = Get-CIEMConfig
    }

    $authConfig = $script:Config.azure.authentication
    $authMethod = $authConfig.method

    Write-CIEMLog -Message "Authentication method from config: $authMethod" -Severity INFO -Component 'Connect-CIEMAzure'
    Write-Verbose "Azure authentication method: $authMethod"

    # Check if running in PSU context (Secret: drive available)
    $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
    Write-CIEMLog -Message "PSU context detected: $inPSUContext" -Severity INFO -Component 'Connect-CIEMAzure'

    # Variable to track tenant info for context creation
    $tenantId = $null

    switch ($authMethod) {
        'ServicePrincipalSecret' {
            Write-CIEMLog -Message "Processing ServicePrincipalSecret authentication via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'

            # TenantId and ClientId come from PSU cache
            $tenantId = $authConfig.tenantId
            $clientId = $authConfig.servicePrincipal.clientId
            Write-CIEMLog -Message "PSU cache - TenantId: $(if($tenantId){'found'}else{'null'}), ClientId: $(if($clientId){'found'}else{'null'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            # ClientSecret comes from PSU secret
            Write-CIEMLog -Message "Checking PSU secret for ClientSecret..." -Severity DEBUG -Component 'Connect-CIEMAzure'
            $clientSecret = Get-CIEMSecret 'CIEM_Azure_ClientSecret'
            Write-CIEMLog -Message "PSU secret - ClientSecret: $(if($clientSecret){'found'}else{'null'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            # Final credential summary
            Write-CIEMLog -Message "Final credentials - TenantId: $(if($tenantId){$tenantId.Substring(0,8)+'...'}else{'MISSING'}), ClientId: $(if($clientId){$clientId.Substring(0,8)+'...'}else{'MISSING'}), ClientSecret: $(if($clientSecret){'SET'}else{'MISSING'})" -Severity INFO -Component 'Connect-CIEMAzure'

            if (-not $clientId -or -not $clientSecret -or -not $tenantId) {
                $errorMsg = @"
Authentication method is 'ServicePrincipalSecret' but credentials not found.

Credential sources:
  TenantId: PSU cache -> azure.authentication.tenantId $(if($tenantId){'[FOUND]'}else{'[MISSING]'})
  ClientId: PSU cache -> azure.authentication.servicePrincipal.clientId $(if($clientId){'[FOUND]'}else{'[MISSING]'})
  ClientSecret: PSU secret -> CIEM_Azure_ClientSecret $(if($clientSecret){'[FOUND]'}else{'[MISSING]'})

$(if (-not $inPSUContext) { "NOTE: Not running in PSU context - PSU secrets are not available." })
"@
                Write-CIEMLog -Message "Credential validation failed: TenantId=$(if($tenantId){'ok'}else{'MISSING'}), ClientId=$(if($clientId){'ok'}else{'MISSING'}), ClientSecret=$(if($clientSecret){'ok'}else{'MISSING'})" -Severity ERROR -Component 'Connect-CIEMAzure'
                throw $errorMsg
            }

            $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

            # Get ARM token via REST API (avoids MSAL library issues on Linux)
            Write-CIEMLog -Message "Requesting ARM token via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $armBody = @{
                client_id     = $clientId
                scope         = 'https://management.azure.com/.default'
                client_secret = $clientSecret
                grant_type    = 'client_credentials'
            }
            $armTokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $armBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            Write-CIEMLog -Message "ARM token obtained (expires in $($armTokenResponse.expires_in)s)" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get Graph token via REST API (same pattern as ARM token)
            Write-CIEMLog -Message "Requesting Graph token via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $graphBody = @{
                client_id     = $clientId
                scope         = 'https://graph.microsoft.com/.default'
                client_secret = $clientSecret
                grant_type    = 'client_credentials'
            }
            $graphTokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $graphBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            Write-CIEMLog -Message "Graph token obtained (expires in $($graphTokenResponse.expires_in)s)" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get KeyVault token via REST API (for Key Vault data plane access)
            Write-CIEMLog -Message "Requesting KeyVault token via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $keyVaultBody = @{
                client_id     = $clientId
                scope         = 'https://vault.azure.net/.default'
                client_secret = $clientSecret
                grant_type    = 'client_credentials'
            }
            $keyVaultTokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $keyVaultBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
            Write-CIEMLog -Message "KeyVault token obtained (expires in $($keyVaultTokenResponse.expires_in)s)" -Severity INFO -Component 'Connect-CIEMAzure'

            # Store tokens via centralized helper
            Save-CIEMToken -ARMToken $armTokenResponse.access_token -GraphToken $graphTokenResponse.access_token -KeyVaultToken $keyVaultTokenResponse.access_token
            Write-CIEMLog -Message "Tokens saved" -Severity INFO -Component 'Connect-CIEMAzure'

            # Inject ARM token into Az context
            Write-CIEMLog -Message "Injecting ARM token into Az context via Connect-AzAccount -AccessToken..." -Severity INFO -Component 'Connect-CIEMAzure'
            Connect-AzAccount -AccessToken $armTokenResponse.access_token -AccountId $clientId -TenantId $tenantId -ErrorAction Stop | Out-Null
            Write-CIEMLog -Message "Az context established successfully" -Severity INFO -Component 'Connect-CIEMAzure'
        }
        'ServicePrincipalCertificate' {
            Write-CIEMLog -Message "Processing ServicePrincipalCertificate authentication..." -Severity INFO -Component 'Connect-CIEMAzure'

            # TenantId and ClientId come from PSU cache
            $tenantId = $authConfig.tenantId
            $clientId = $authConfig.servicePrincipal.clientId
            Write-CIEMLog -Message "PSU cache - TenantId: $(if($tenantId){'found'}else{'null'}), ClientId: $(if($clientId){'found'}else{'null'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            # Thumbprint comes from PSU secret
            Write-CIEMLog -Message "Checking PSU secret for CertThumbprint..." -Severity DEBUG -Component 'Connect-CIEMAzure'
            $thumbprint = Get-CIEMSecret 'CIEM_Azure_CertThumbprint'
            Write-CIEMLog -Message "PSU secret - CertThumbprint: $(if($thumbprint){'found'}else{'null'})" -Severity DEBUG -Component 'Connect-CIEMAzure'

            Write-CIEMLog -Message "Certificate auth credentials - TenantId: $(if($tenantId){'found'}else{'null'}), ClientId: $(if($clientId){'found'}else{'null'}), Thumbprint: $(if($thumbprint){'found'}else{'null'})" -Severity INFO -Component 'Connect-CIEMAzure'

            if (-not $clientId -or -not $tenantId) {
                Write-CIEMLog -Message "Certificate auth failed: missing TenantId or ClientId" -Severity ERROR -Component 'Connect-CIEMAzure'
                throw "Authentication method is 'ServicePrincipalCertificate' but tenantId or clientId not found in PSU cache"
            }

            if (-not $thumbprint) {
                Write-CIEMLog -Message "Certificate auth failed: no thumbprint provided" -Severity ERROR -Component 'Connect-CIEMAzure'
                throw "Certificate authentication requires thumbprint in PSU secret (CIEM_Azure_CertThumbprint)"
            }

            # Certificate auth still uses Connect-AzAccount directly (requires local cert store)
            $connectParams = @{
                ServicePrincipal         = $true
                ApplicationId            = $clientId
                TenantId                 = $tenantId
                CertificateThumbprint    = $thumbprint
            }
            Write-CIEMLog -Message "Using certificate thumbprint for authentication" -Severity DEBUG -Component 'Connect-CIEMAzure'

            Write-CIEMLog -Message "Calling Connect-AzAccount with certificate..." -Severity INFO -Component 'Connect-CIEMAzure'
            Write-Verbose "Connecting with certificate for: $clientId"
            Connect-AzAccount @connectParams -ErrorAction Stop | Out-Null
            Write-CIEMLog -Message "Certificate authentication completed successfully" -Severity INFO -Component 'Connect-CIEMAzure'

            # Acquire Graph token using Get-AzAccessToken
            Write-CIEMLog -Message "Acquiring Graph token via Get-AzAccessToken..." -Severity INFO -Component 'Connect-CIEMAzure'
            $graphTokenResponse = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -ErrorAction Stop
            Save-CIEMToken -GraphToken $graphTokenResponse.Token
            Write-CIEMLog -Message "Graph token saved" -Severity INFO -Component 'Connect-CIEMAzure'
        }
        'ManagedIdentity' {
            Write-CIEMLog -Message "Processing ManagedIdentity authentication via REST API..." -Severity INFO -Component 'Connect-CIEMAzure'

            # Check for user-assigned managed identity config (optional)
            $miClientId = $null
            if ($authConfig.PSObject.Properties['managedIdentity'] -and $authConfig.managedIdentity.clientId) {
                $miClientId = $authConfig.managedIdentity.clientId
                Write-CIEMLog -Message "Using user-assigned managed identity: $miClientId" -Severity INFO -Component 'Connect-CIEMAzure'
            }
            else {
                Write-CIEMLog -Message "Using system-assigned managed identity" -Severity INFO -Component 'Connect-CIEMAzure'
            }

            # Azure App Service provides MSI endpoint via environment variables
            $identityEndpoint = $env:IDENTITY_ENDPOINT
            $identityHeader = $env:IDENTITY_HEADER

            if (-not $identityEndpoint -or -not $identityHeader) {
                Write-CIEMLog -Message "MSI environment variables not found. IDENTITY_ENDPOINT=$(if($identityEndpoint){'set'}else{'not set'}), IDENTITY_HEADER=$(if($identityHeader){'set'}else{'not set'})" -Severity ERROR -Component 'Connect-CIEMAzure'
                throw "Managed Identity environment not detected. IDENTITY_ENDPOINT and IDENTITY_HEADER must be set (Azure App Service MSI)."
            }

            Write-CIEMLog -Message "MSI endpoint detected: $identityEndpoint" -Severity DEBUG -Component 'Connect-CIEMAzure'

            # Helper function to get token via MSI endpoint
            $getMsiToken = {
                param([string]$Resource)
                $tokenUri = "$identityEndpoint`?api-version=2019-08-01&resource=$Resource"
                if ($miClientId) {
                    $tokenUri += "&client_id=$miClientId"
                }
                $headers = @{ 'X-IDENTITY-HEADER' = $identityHeader }
                $response = Invoke-RestMethod -Uri $tokenUri -Headers $headers -Method Get -ErrorAction Stop
                return $response
            }

            # Get ARM token via MSI REST API
            Write-CIEMLog -Message "Requesting ARM token via MSI REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $armTokenResponse = & $getMsiToken -Resource 'https://management.azure.com/'
            Write-CIEMLog -Message "ARM token obtained (expires: $($armTokenResponse.expires_on))" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get Graph token via MSI REST API
            Write-CIEMLog -Message "Requesting Graph token via MSI REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $graphTokenResponse = & $getMsiToken -Resource 'https://graph.microsoft.com/'
            Write-CIEMLog -Message "Graph token obtained (expires: $($graphTokenResponse.expires_on))" -Severity INFO -Component 'Connect-CIEMAzure'

            # Get KeyVault token via MSI REST API
            Write-CIEMLog -Message "Requesting KeyVault token via MSI REST API..." -Severity INFO -Component 'Connect-CIEMAzure'
            $keyVaultTokenResponse = & $getMsiToken -Resource 'https://vault.azure.net/'
            Write-CIEMLog -Message "KeyVault token obtained (expires: $($keyVaultTokenResponse.expires_on))" -Severity INFO -Component 'Connect-CIEMAzure'

            # Store tokens via centralized helper
            Save-CIEMToken -ARMToken $armTokenResponse.access_token -GraphToken $graphTokenResponse.access_token -KeyVaultToken $keyVaultTokenResponse.access_token
            Write-CIEMLog -Message "Tokens saved" -Severity INFO -Component 'Connect-CIEMAzure'

            # Extract tenant ID from ARM token (JWT payload contains tid claim)
            $tokenParts = $armTokenResponse.access_token.Split('.')
            $payload = $tokenParts[1]
            # Add padding if needed for base64 decode
            $padLength = 4 - ($payload.Length % 4)
            if ($padLength -lt 4) { $payload += ('=' * $padLength) }
            $decodedPayload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
            $tokenClaims = $decodedPayload | ConvertFrom-Json
            $tenantId = $tokenClaims.tid
            $accountId = $tokenClaims.oid  # Object ID of the managed identity
            Write-CIEMLog -Message "Extracted from token - TenantId: $tenantId, ObjectId: $accountId" -Severity DEBUG -Component 'Connect-CIEMAzure'

            # Inject ARM token into Az context
            Write-CIEMLog -Message "Injecting ARM token into Az context via Connect-AzAccount -AccessToken..." -Severity INFO -Component 'Connect-CIEMAzure'
            Connect-AzAccount -AccessToken $armTokenResponse.access_token -AccountId $accountId -TenantId $tenantId -ErrorAction Stop | Out-Null
            Write-CIEMLog -Message "Az context established successfully via Managed Identity" -Severity INFO -Component 'Connect-CIEMAzure'
        }
        'DeviceCode' {
            Write-CIEMLog -Message "Processing DeviceCode authentication..." -Severity INFO -Component 'Connect-CIEMAzure'
            $connectParams = @{ UseDeviceAuthentication = $true }
            if ($authConfig.tenantId) {
                $connectParams.TenantId = $authConfig.tenantId
                Write-CIEMLog -Message "Using tenant: $($authConfig.tenantId)" -Severity DEBUG -Component 'Connect-CIEMAzure'
            }
            Write-CIEMLog -Message "Calling Connect-AzAccount with device code..." -Severity INFO -Component 'Connect-CIEMAzure'
            Write-Verbose "Connecting with device code authentication"
            Connect-AzAccount @connectParams -ErrorAction Stop | Out-Null
            Write-CIEMLog -Message "Device code authentication completed successfully" -Severity INFO -Component 'Connect-CIEMAzure'

            # Acquire Graph token using Get-AzAccessToken
            Write-CIEMLog -Message "Acquiring Graph token via Get-AzAccessToken..." -Severity INFO -Component 'Connect-CIEMAzure'
            $graphTokenResponse = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -ErrorAction Stop
            Save-CIEMToken -GraphToken $graphTokenResponse.Token
            Write-CIEMLog -Message "Graph token saved" -Severity INFO -Component 'Connect-CIEMAzure'
        }
        'Interactive' {
            Write-CIEMLog -Message "Processing Interactive authentication..." -Severity INFO -Component 'Connect-CIEMAzure'
            $connectParams = @{}
            if ($authConfig.tenantId) {
                $connectParams.TenantId = $authConfig.tenantId
                Write-CIEMLog -Message "Using tenant: $($authConfig.tenantId)" -Severity DEBUG -Component 'Connect-CIEMAzure'
            }
            Write-CIEMLog -Message "Calling Connect-AzAccount interactively..." -Severity INFO -Component 'Connect-CIEMAzure'
            Write-Verbose "Connecting with interactive authentication"
            Connect-AzAccount @connectParams -ErrorAction Stop | Out-Null
            Write-CIEMLog -Message "Interactive authentication completed successfully" -Severity INFO -Component 'Connect-CIEMAzure'

            # Acquire Graph token using Get-AzAccessToken
            Write-CIEMLog -Message "Acquiring Graph token via Get-AzAccessToken..." -Severity INFO -Component 'Connect-CIEMAzure'
            $graphTokenResponse = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -ErrorAction Stop
            Save-CIEMToken -GraphToken $graphTokenResponse.Token
            Write-CIEMLog -Message "Graph token saved" -Severity INFO -Component 'Connect-CIEMAzure'
        }
        default {
            Write-CIEMLog -Message "Unknown authentication method: $authMethod" -Severity ERROR -Component 'Connect-CIEMAzure'
            throw "Unknown authentication method '$authMethod'. Valid values: ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity, DeviceCode, Interactive"
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
                Write-CIEMLog -Message "Clearing Az context and waiting before retry..." -Severity DEBUG -Component 'Connect-CIEMAzure'
                Clear-AzContext -Force -ErrorAction SilentlyContinue | Out-Null
                Start-Sleep -Milliseconds 500
            }
            else {
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
    $subscriptionFilter = @($script:Config.azure.subscriptionFilter)
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
        Write-Verbose "Found $($subscriptionIds.Count) accessible subscription(s)"
    }

    # Determine account type
    $accountType = switch ($context.Account.Type) {
        'User' { 'User' }
        'ServicePrincipal' { 'ServicePrincipal' }
        'ManagedService' { 'ManagedIdentity' }
        default { $context.Account.Type }
    }
    Write-CIEMLog -Message "Account type determined: $accountType" -Severity DEBUG -Component 'Connect-CIEMAzure'

    Write-CIEMLog -Message "Connect-CIEMAzure completed successfully" -Severity INFO -Component 'Connect-CIEMAzure'

    [PSCustomObject]@{
        TenantId        = $context.Tenant.Id
        SubscriptionIds = $subscriptionIds
        AccountId       = $context.Account.Id
        AccountType     = $accountType
        ConnectedAt     = Get-Date
    }
}
