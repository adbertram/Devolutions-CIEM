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
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Secret is already in memory from config file; conversion to SecureString is required for Connect-AzAccount')]
    [OutputType([PSCustomObject])]
    param()

    $ErrorActionPreference = 'Stop'

    $authConfig = $script:Config.azure.authentication
    $authMethod = $authConfig.method

    Write-Verbose "Azure authentication method: $authMethod"

    switch ($authMethod) {
        'ServicePrincipalSecret' {
            $spConfig = $authConfig.servicePrincipal
            if (-not $spConfig.clientId -or -not $spConfig.clientSecret -or -not $authConfig.tenantId) {
                throw "Authentication method is 'ServicePrincipalSecret' but tenantId, clientId, or clientSecret not set in config.json"
            }

            $secureSecret = ConvertTo-SecureString $spConfig.clientSecret -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($spConfig.clientId, $secureSecret)

            Write-Verbose "Connecting as service principal: $($spConfig.clientId)"
            Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $authConfig.tenantId -ErrorAction Stop | Out-Null
        }
        'ServicePrincipalCertificate' {
            $certConfig = $authConfig.certificate
            if (-not $certConfig.clientId -or -not $authConfig.tenantId) {
                throw "Authentication method is 'ServicePrincipalCertificate' but tenantId or clientId not set in config.json"
            }

            $connectParams = @{
                ServicePrincipal        = $true
                ApplicationId           = $certConfig.clientId
                TenantId                = $authConfig.tenantId
            }

            if ($certConfig.thumbprint) {
                $connectParams.CertificateThumbprint = $certConfig.thumbprint
            }
            elseif ($certConfig.path) {
                $connectParams.CertificatePath = $certConfig.path
                if ($certConfig.password) {
                    $connectParams.CertificatePassword = ConvertTo-SecureString $certConfig.password -AsPlainText -Force
                }
            }
            else {
                throw "Certificate authentication requires either thumbprint or path in config.json"
            }

            Write-Verbose "Connecting with certificate for: $($certConfig.clientId)"
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
