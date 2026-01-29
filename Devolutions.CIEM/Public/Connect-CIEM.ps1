function Connect-CIEM {
    <#
    .SYNOPSIS
        Establishes authentication to all configured cloud providers for CIEM scans.

    .DESCRIPTION
        Reads authentication configuration from config.json and connects to each
        enabled cloud provider. This function must be called once before running
        any CIEM scans. The connection is cached for the duration of the PowerShell
        session.

        Currently supports:
        - Azure (ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity, Interactive)
        - AWS (coming soon)

    .PARAMETER Provider
        Optional. Connect only to specific provider(s). If not specified, connects
        to the provider defined in config.json's cloudProvider setting.

    .PARAMETER Force
        Force re-authentication even if already connected.

    .OUTPUTS
        [PSCustomObject] Connection summary showing status for each provider.

    .EXAMPLE
        Connect-CIEM
        # Connects to the default provider from config.json

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
        [ValidateSet('Azure', 'AWS')]
        [string[]]$Provider,

        [Parameter()]
        [switch]$Force
    )

    $ErrorActionPreference = 'Stop'

    # Initialize auth context storage if not exists
    if (-not $script:AuthContext) {
        $script:AuthContext = @{}
    }

    # Determine which providers to connect
    if (-not $Provider) {
        $Provider = @($script:Config.cloudProvider)
    }

    $results = @()

    foreach ($p in $Provider) {
        Write-Verbose "Connecting to provider: $p"

        # Skip if already connected and not forcing
        if (-not $Force -and $script:AuthContext[$p]) {
            Write-Verbose "$p is already connected. Use -Force to re-authenticate."
            $results += [PSCustomObject]@{
                Provider = $p
                Status   = 'AlreadyConnected'
                Account  = $script:AuthContext[$p].AccountId
                TenantId = $script:AuthContext[$p].TenantId
                Message  = 'Already authenticated. Use -Force to re-authenticate.'
            }
            continue
        }

        try {
            switch ($p) {
                'Azure' {
                    $authContext = Connect-CIEMAzure
                    $script:AuthContext['Azure'] = $authContext

                    $results += [PSCustomObject]@{
                        Provider      = 'Azure'
                        Status        = 'Connected'
                        Account       = $authContext.AccountId
                        TenantId      = $authContext.TenantId
                        Subscriptions = $authContext.SubscriptionIds.Count
                        Message       = "Connected as $($authContext.AccountType)"
                    }
                }
                'AWS' {
                    # AWS support coming soon
                    $results += [PSCustomObject]@{
                        Provider = 'AWS'
                        Status   = 'NotSupported'
                        Account  = $null
                        TenantId = $null
                        Message  = 'AWS provider support coming soon'
                    }
                }
            }
        }
        catch {
            $script:AuthContext[$p] = $null
            $results += [PSCustomObject]@{
                Provider = $p
                Status   = 'Failed'
                Account  = $null
                TenantId = $null
                Message  = $_.Exception.Message
            }
            Write-Error "Failed to connect to $p : $_"
        }
    }

    # Display summary
    Write-Host "`nCIEM Connection Summary:" -ForegroundColor Cyan
    foreach ($r in $results) {
        $color = switch ($r.Status) {
            'Connected' { 'Green' }
            'AlreadyConnected' { 'Yellow' }
            'Failed' { 'Red' }
            default { 'Gray' }
        }
        Write-Host "  $($r.Provider): " -NoNewline
        Write-Host $r.Status -ForegroundColor $color -NoNewline
        if ($r.Account) {
            Write-Host " ($($r.Account))" -NoNewline
        }
        Write-Host ""
    }

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
        Credential resolution order:
        1. PSU secrets (when running in PowerShell Universal)
        2. .env file in module directory (for local development)
        3. config.json values (legacy, typically null)
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Secret is already in memory from secure source; conversion to SecureString is required for Connect-AzAccount')]
    [OutputType([PSCustomObject])]
    param()

    $ErrorActionPreference = 'Stop'

    $authConfig = $script:Config.azure.authentication
    $authMethod = $authConfig.method

    Write-Verbose "Azure authentication method: $authMethod"

    # Check if running in PSU context (Secret: drive available)
    $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)

    # Load .env file for local development
    $envVars = @{}
    $envPath = Join-Path -Path $script:ModuleRoot -ChildPath '.env'
    if (Test-Path $envPath) {
        Write-Verbose "Loading credentials from .env file..."
        Get-Content $envPath | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $envVars[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }

    switch ($authMethod) {
        'ServicePrincipalSecret' {
            $tenantId = $null
            $clientId = $null
            $clientSecret = $null

            # Priority 1: PSU secrets
            if ($inPSUContext) {
                Write-Verbose "PSU context detected, checking for secrets..."
                $tenantId = $Secret:CIEM_Azure_TenantId
                $clientId = $Secret:CIEM_Azure_ClientId
                $clientSecret = $Secret:CIEM_Azure_ClientSecret
            }

            # Priority 2: .env file
            if (-not $tenantId) { $tenantId = $envVars['CIEM_AZURE_TENANT_ID'] }
            if (-not $clientId) { $clientId = $envVars['CIEM_AZURE_CLIENT_ID'] }
            if (-not $clientSecret) { $clientSecret = $envVars['CIEM_AZURE_CLIENT_SECRET'] }

            # Priority 3: config.json (legacy fallback)
            if (-not $tenantId) { $tenantId = $authConfig.tenantId }
            if (-not $clientId) { $clientId = $authConfig.servicePrincipal.clientId }
            if (-not $clientSecret) { $clientSecret = $authConfig.servicePrincipal.clientSecret }

            if (-not $clientId -or -not $clientSecret -or -not $tenantId) {
                $errorMsg = @"
Authentication method is 'ServicePrincipalSecret' but credentials not found.

Credential sources checked (in order):
$(if ($inPSUContext) { "  1. PSU secrets: CIEM_Azure_TenantId, CIEM_Azure_ClientId, CIEM_Azure_ClientSecret" } else { "  1. PSU secrets: (not in PSU context)" })
  2. .env file: $(if (Test-Path $envPath) { $envPath } else { '(not found)' })
  3. config.json: tenantId, servicePrincipal.clientId, servicePrincipal.clientSecret

For local development, create a .env file in the module directory with:
  CIEM_AZURE_TENANT_ID=<tenant-id>
  CIEM_AZURE_CLIENT_ID=<client-id>
  CIEM_AZURE_CLIENT_SECRET=<client-secret>
"@
                throw $errorMsg
            }

            $secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($clientId, $secureSecret)

            Write-Verbose "Connecting as service principal: $clientId"
            Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $tenantId -ErrorAction Stop | Out-Null
        }
        'ServicePrincipalCertificate' {
            $tenantId = $null
            $clientId = $null
            $thumbprint = $null

            # Priority 1: PSU secrets
            if ($inPSUContext) {
                Write-Verbose "PSU context detected, checking for certificate secrets..."
                $tenantId = $Secret:CIEM_Azure_TenantId
                $clientId = $Secret:CIEM_Azure_ClientId
                $thumbprint = $Secret:CIEM_Azure_CertThumbprint
            }

            # Priority 2: .env file
            if (-not $tenantId) { $tenantId = $envVars['CIEM_AZURE_TENANT_ID'] }
            if (-not $clientId) { $clientId = $envVars['CIEM_AZURE_CLIENT_ID'] }
            if (-not $thumbprint) { $thumbprint = $envVars['CIEM_AZURE_CERT_THUMBPRINT'] }

            if (-not $clientId -or -not $tenantId) {
                throw "Authentication method is 'ServicePrincipalCertificate' but tenantId or clientId not found in PSU secrets or .env file"
            }

            $connectParams = @{
                ServicePrincipal = $true
                ApplicationId    = $clientId
                TenantId         = $tenantId
            }

            if ($thumbprint) {
                $connectParams.CertificateThumbprint = $thumbprint
            }
            else {
                throw "Certificate authentication requires thumbprint in PSU secrets (CIEM_Azure_CertThumbprint) or .env file (CIEM_AZURE_CERT_THUMBPRINT)"
            }

            Write-Verbose "Connecting with certificate for: $clientId"
            Connect-AzAccount @connectParams -ErrorAction Stop | Out-Null
        }
        'ManagedIdentity' {
            $miConfig = $authConfig.managedIdentity
            $connectParams = @{ Identity = $true }

            if ($miConfig.clientId) {
                $connectParams.AccountId = $miConfig.clientId
                Write-Verbose "Connecting with user-assigned managed identity: $($miConfig.clientId)"
            }
            else {
                Write-Verbose "Connecting with system-assigned managed identity"
            }

            Connect-AzAccount @connectParams -ErrorAction Stop | Out-Null
        }
        'DeviceCode' {
            $connectParams = @{ UseDeviceAuthentication = $true }
            if ($authConfig.tenantId) {
                $connectParams.TenantId = $authConfig.tenantId
            }
            Write-Verbose "Connecting with device code authentication"
            Connect-AzAccount @connectParams -ErrorAction Stop | Out-Null
        }
        'Interactive' {
            $connectParams = @{}
            if ($authConfig.tenantId) {
                $connectParams.TenantId = $authConfig.tenantId
            }
            Write-Verbose "Connecting with interactive authentication"
            Connect-AzAccount @connectParams -ErrorAction Stop | Out-Null
        }
        default {
            throw "Unknown authentication method '$authMethod'. Valid values: ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity, DeviceCode, Interactive"
        }
    }

    $context = Get-AzContext -ErrorAction Stop

    # Get all accessible subscriptions
    $subscriptions = Get-AzSubscription -TenantId $context.Tenant.Id -ErrorAction SilentlyContinue

    # Filter to configured subscriptions if specified
    $subscriptionFilter = $script:Config.azure.subscriptionFilter
    if ($subscriptionFilter -and $subscriptionFilter.Count -gt 0) {
        $subscriptions = $subscriptions | Where-Object { $subscriptionFilter -contains $_.Id }
    }

    $subscriptionIds = @($subscriptions | Select-Object -ExpandProperty Id)

    if ($subscriptionIds.Count -eq 0) {
        Write-Warning "No accessible subscriptions found in tenant $($context.Tenant.Id)"
    }
    else {
        Write-Verbose "Found $($subscriptionIds.Count) accessible subscription(s)"
    }

    # Determine account type
    $accountType = switch ($context.Account.Type) {
        'User' { 'User' }
        'ServicePrincipal' { 'ServicePrincipal' }
        'ManagedService' { 'ManagedIdentity' }
        default { $context.Account.Type }
    }

    [PSCustomObject]@{
        TenantId        = $context.Tenant.Id
        SubscriptionIds = $subscriptionIds
        AccountId       = $context.Account.Id
        AccountType     = $accountType
        ConnectedAt     = Get-Date
    }
}
