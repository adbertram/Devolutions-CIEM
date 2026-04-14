function Connect-CIEM {
    <#
    .SYNOPSIS
        Establishes authentication to all configured cloud providers for CIEM scans.

    .DESCRIPTION
        Reads authentication configuration from the database and connects to each
        enabled cloud provider. This function must be called once before running
        any CIEM scans. The connection is cached for the duration of the PowerShell
        session.

        Provider-specific connector functions are discovered dynamically by naming
        convention: Connect-CIEM<ProviderName> (e.g., Connect-CIEMAzure from the
        Devolutions.CIEM.Azure module).

    .PARAMETER Provider
        Optional. Connect only to specific provider(s). If not specified, connects
        to the default provider defined in the database.

    .PARAMETER AuthenticationProfile
        Optional. A pre-resolved authentication profile object to pass to the
        provider connector (e.g., CIEMAzureAuthenticationProfile). If not
        provided, the connector looks up the active profile automatically.

    .PARAMETER Force
        Force re-authentication even if already connected.

    .OUTPUTS
        [PSCustomObject] Connection summary showing status for each provider.

    .EXAMPLE
        Connect-CIEM
        # Connects to the default provider

    .EXAMPLE
        Connect-CIEM -Provider Azure
        # Connects only to a specific provider

    .EXAMPLE
        Connect-CIEM -Force
        # Forces re-authentication even if already connected

    .NOTES
        This function must be called before running InvokeCIEMScan or any other
        scan functions.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string[]]$Provider,

        [Parameter()]
        $AuthenticationProfile,

        [Parameter()]
        [switch]$Force
    )

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    Write-CIEMLog -Message "Connect-CIEM called with Provider=[$($Provider -join ',')] Force=$Force" -Severity INFO -Component 'Connect-CIEM'

    # Initialize auth context storage if not exists
    if (-not $script:AuthContext) {
        $script:AuthContext = @{}
        Write-CIEMLog -Message "Initialized empty AuthContext" -Severity DEBUG -Component 'Connect-CIEM'
    }

    # Determine which providers to connect
    if (-not $Provider) {
        $allProviders = Get-CIEMProvider
        $defaultProvider = ($allProviders | Where-Object Enabled | Select-Object -First 1).Name
        if (-not $defaultProvider) {
            throw "No providers configured. Ensure the database has been initialized with provider rows."
        }
        $Provider = @($defaultProvider)
        Write-CIEMLog -Message "No provider specified, using default: $defaultProvider" -Severity DEBUG -Component 'Connect-CIEM'
    }

    Write-CIEMLog -Message "Providers to connect: $($Provider -join ', ')" -Severity INFO -Component 'Connect-CIEM'

    # Use List for efficient collection (summary returned at end)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($p in $Provider) {
        Write-CIEMLog -Message "Processing provider: $p" -Severity INFO -Component 'Connect-CIEM'
        Write-Verbose "Connecting to provider: $p"

        # Skip if already connected and not forcing
        # Cast enum to string for hashtable key lookup (enum keys != string keys)
        $providerKey = $p.ToString()

        if (-not $Force.IsPresent -and $script:AuthContext[$providerKey]) {
            $existing = $script:AuthContext[$providerKey]
            Write-CIEMLog -Message "$p is already connected (AccountId: $($existing.AccountId)). Skipping." -Severity INFO -Component 'Connect-CIEM'
            Write-Verbose "$p is already connected. Use -Force to re-authenticate."
            $results.Add([PSCustomObject]@{
                Provider        = $p
                Status          = 'AlreadyConnected'
                Account         = $existing.AccountId
                TenantId        = $existing.TenantId
                SubscriptionIds = @($existing.SubscriptionIds)
                Message         = 'Already authenticated. Use -Force to re-authenticate.'
            })
            continue
        }

        # Discover provider-specific connector function dynamically
        $connectorName = "Connect-CIEM$p"
        $connectorCmd = Get-Command -Name $connectorName -ErrorAction SilentlyContinue

        if (-not $connectorCmd) {
            throw "Provider connector function '$connectorName' not found. Ensure the Devolutions.CIEM.$p module is imported."
        }

        Write-CIEMLog -Message "Calling $connectorName..." -Severity INFO -Component 'Connect-CIEM'
        $connectorParams = @{}
        if ($AuthenticationProfile) { $connectorParams.AuthenticationProfile = $AuthenticationProfile }
        $authContext = & $connectorCmd @connectorParams
        $script:AuthContext[$providerKey] = $authContext

        # Build result based on what the auth context provides
        $resultObj = [PSCustomObject]@{
            Provider = $p
            Status   = 'Connected'
            Account  = $authContext.AccountId
            TenantId = if ($authContext.PSObject.Properties['TenantId']) { $authContext.TenantId } else { $null }
            Message  = "Connected as $($authContext.AccountType)"
        }

        # Add provider-specific properties
        if ($authContext.PSObject.Properties['SubscriptionIds']) {
            $resultObj | Add-Member -NotePropertyName 'Subscriptions' -NotePropertyValue @($authContext.SubscriptionIds).Count
            $resultObj | Add-Member -NotePropertyName 'SubscriptionIds' -NotePropertyValue @($authContext.SubscriptionIds)
        }

        Write-CIEMLog -Message "$p connection successful. AccountId: $($authContext.AccountId)" -Severity INFO -Component 'Connect-CIEM'
        $results.Add($resultObj)
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
