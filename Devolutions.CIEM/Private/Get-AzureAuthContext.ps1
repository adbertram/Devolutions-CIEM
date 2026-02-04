function Get-AzureAuthContext {
    <#
    .SYNOPSIS
        Gets or establishes Azure authentication context for CIEM scans.

    .DESCRIPTION
        Validates existing Azure authentication or establishes a new connection.
        Supports auto-detection of authentication method (Managed Identity,
        Service Principal via environment, Azure CLI, or interactive).

        Returns authentication context with tenant ID, subscription IDs, and account info.

    .PARAMETER TenantId
        Optional tenant ID to use. If not specified, uses the current context tenant
        or the tenant from CIEM config.

    .OUTPUTS
        [hashtable] Authentication context containing:
        - TenantId: The Azure AD tenant ID
        - SubscriptionIds: Array of accessible subscription IDs
        - AccountId: The authenticated account identifier
        - AccountType: Type of account (User, ServicePrincipal, ManagedIdentity)

    .EXAMPLE
        $authContext = Get-AzureAuthContext
        $authContext.TenantId  # Returns tenant GUID

    .EXAMPLE
        $authContext = Get-AzureAuthContext -TenantId '12345678-1234-1234-1234-123456789012'
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Secret is already in memory from config file; conversion to SecureString is required for Connect-AzAccount')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$TenantId
    )

    $ErrorActionPreference = 'Stop'

    # Check authentication method from config
    $authMethod = $script:Config.azure.authentication.method

    # Get existing Azure context
    $context = Get-AzContext -ErrorAction SilentlyContinue

    switch ($authMethod) {
        'ServicePrincipalSecret' {
            $authConfig = $script:Config.azure.authentication
            $spConfig = $authConfig.servicePrincipal
            if (-not $spConfig.clientId -or -not $spConfig.clientSecret -or -not $authConfig.tenantId) {
                throw "Authentication method is 'ServicePrincipalSecret' but tenantId, clientId, or clientSecret not set in CIEM config"
            }

            $secureSecret = ConvertTo-SecureString $spConfig.clientSecret -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($spConfig.clientId, $secureSecret)

            Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $authConfig.tenantId -ErrorAction Stop | Out-Null
            $context = Get-AzContext -ErrorAction Stop
            Write-Verbose "Authenticated as service principal: $($spConfig.clientId)"
        }
        'ManagedIdentity' {
            Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
            $context = Get-AzContext -ErrorAction Stop
            Write-Verbose "Authenticated using Managed Identity"
        }
        'Interactive' {
            if (-not $context) {
                Write-Verbose "No existing context. Prompting for interactive login..."
                $connectParams = @{}
                if ($TenantId) {
                    $connectParams.TenantId = $TenantId
                }
                Connect-AzAccount @connectParams -UseDeviceAuthentication -ErrorAction Stop | Out-Null
                $context = Get-AzContext -ErrorAction Stop
            }
            Write-Verbose "Using context: $($context.Account.Id)"
        }
        default {
            throw "Unknown authentication method '$authMethod'. Valid values: ServicePrincipalSecret, ServicePrincipalCertificate, ManagedIdentity, DeviceCode, Interactive"
        }
    }

    # Switch tenant if specified and different from current
    if ($TenantId -and $context.Tenant.Id -ne $TenantId) {
        Write-Verbose "Switching to tenant: $TenantId"
        Set-AzContext -TenantId $TenantId -ErrorAction Stop | Out-Null
        $context = Get-AzContext -ErrorAction Stop
    }

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

    # Determine account type
    $accountType = switch ($context.Account.Type) {
        'User' { 'User' }
        'ServicePrincipal' { 'ServicePrincipal' }
        'ManagedService' { 'ManagedIdentity' }
        default { $context.Account.Type }
    }

    # Test API access
    Write-Verbose "Testing Graph API access..."
    $graphApiBase = $script:Config.azure.endpoints.graphApi
    try {
        $graphTest = Invoke-AzureApi -Uri "$graphApiBase/organization" -Api Graph -ResourceName 'Organization' -ErrorAction Stop
        if (-not $graphTest) {
            Write-Warning "Graph API access may be limited"
        }
    }
    catch {
        Write-Warning "Unable to access Graph API: $($_.Exception.Message)"
    }

    Write-Verbose "Testing ARM API access..."
    $armApiBase = $script:Config.azure.endpoints.armApi
    try {
        $armTest = Invoke-AzureApi -Uri "$armApiBase/subscriptions?api-version=2020-01-01" -Api ARM -ResourceName 'Subscriptions' -ErrorAction Stop
        if (-not $armTest) {
            Write-Warning "ARM API access may be limited"
        }
    }
    catch {
        Write-Warning "Unable to access ARM API: $($_.Exception.Message)"
    }

    [PSCustomObject]@{
        TenantId        = $context.Tenant.Id
        SubscriptionIds = $subscriptionIds
        AccountId       = $context.Account.Id
        AccountType     = $accountType
    }
}
