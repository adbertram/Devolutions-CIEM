function Get-CIEMAuthenticationContext {
    <#
    .SYNOPSIS
        Returns the current authentication context for CIEM providers.

    .DESCRIPTION
        Shows the configured authentication method and current authentication state
        for the specified cloud provider. Useful for verifying authentication setup
        before running scans.

    .PARAMETER Provider
        The cloud provider to get authentication context for. Currently only 'Azure' is supported.

    .OUTPUTS
        [PSCustomObject] Object containing:
        - Provider: The cloud provider name
        - ConfiguredMethod: Authentication method from CIEM config
        - IsAuthenticated: Whether a valid context exists
        - AccountId: The authenticated account identifier
        - AccountType: Type of account (User, ServicePrincipal, ManagedIdentity)
        - TenantId: The tenant/directory ID
        - TenantDomain: The tenant primary domain (if available)
        - SubscriptionCount: Number of accessible subscriptions
        - SubscriptionFilter: Configured subscription filter (if any)
        - Subscriptions: Array of subscription details

    .EXAMPLE
        Get-CIEMAuthenticationContext -Provider Azure
        # Returns Azure authentication context

    .EXAMPLE
        Get-CIEMAuthenticationContext -Provider Azure | Select-Object AccountId, AccountType, TenantId
        # Returns specific authentication details
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Azure')]
        [string]$Provider
    )

    $ErrorActionPreference = 'Stop'

    switch ($Provider) {
        'Azure' { Get-AzureAuthenticationContext }
    }
}

function Get-AzureAuthenticationContext {
    <#
    .SYNOPSIS
        Internal function to get Azure authentication context.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Get configured authentication method
    $configuredMethod = $script:Config.azure.authentication.method
    $subscriptionFilter = $script:Config.azure.subscriptionFilter

    # Check for existing Az PowerShell context
    $context = Get-AzContext -ErrorAction SilentlyContinue

    if (-not $context) {
        [PSCustomObject]@{
            Provider           = 'Azure'
            ConfiguredMethod   = $configuredMethod
            IsAuthenticated    = $false
            AccountId          = $null
            AccountType        = $null
            TenantId           = $null
            TenantDomain       = $null
            SubscriptionCount  = 0
            SubscriptionFilter = $subscriptionFilter
            Subscriptions      = @()
        }
    }
    else {
        # Determine account type
        $accountType = switch ($context.Account.Type) {
            'User' { 'User' }
            'ServicePrincipal' { 'ServicePrincipal' }
            'ManagedService' { 'ManagedIdentity' }
            default { $context.Account.Type }
        }

        # Get accessible subscriptions
        $subscriptions = @(Get-AzSubscription -TenantId $context.Tenant.Id -ErrorAction SilentlyContinue)

        # Apply subscription filter if configured
        if ($subscriptionFilter -and $subscriptionFilter.Count -gt 0) {
            $subscriptions = @($subscriptions | Where-Object { $subscriptionFilter -contains $_.Id })
        }

        # Build subscription details
        $subscriptionDetails = $subscriptions | ForEach-Object {
            [PSCustomObject]@{
                Id    = $_.Id
                Name  = $_.Name
                State = $_.State
            }
        }

        # Try to get tenant domain
        $tenantDomain = $null
        if ($context.Tenant.Id) {
            $tenant = Get-AzTenant -TenantId $context.Tenant.Id -ErrorAction SilentlyContinue
            if ($tenant -and $tenant.Domains) {
                $tenantDomain = ($tenant.Domains | Where-Object { $_ -notmatch '\.onmicrosoft\.com$' } | Select-Object -First 1) ??
                               ($tenant.Domains | Select-Object -First 1)
            }
        }

        [PSCustomObject]@{
            Provider           = 'Azure'
            ConfiguredMethod   = $configuredMethod
            IsAuthenticated    = $true
            AccountId          = $context.Account.Id
            AccountType        = $accountType
            TenantId           = $context.Tenant.Id
            TenantDomain       = $tenantDomain
            SubscriptionCount  = $subscriptions.Count
            SubscriptionFilter = $subscriptionFilter
            Subscriptions      = @($subscriptionDetails)
        }
    }
}
