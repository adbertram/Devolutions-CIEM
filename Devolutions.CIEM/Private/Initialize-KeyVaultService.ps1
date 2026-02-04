function Initialize-KeyVaultService {
    <#
    .SYNOPSIS
        Initializes the KeyVault service by pre-loading vault configurations.

    .DESCRIPTION
        Loads Azure Key Vault resources from ARM API and caches them in $script:KeyVaultService
        for use by check scripts. Resources are loaded per-subscription.

        Resources loaded:
        - Key Vault configurations (RBAC, soft delete, purge protection, network rules)
        - Diagnostic settings for each vault
        - Keys and secrets (from data plane, requires additional permissions)

    .PARAMETER SubscriptionIds
        Array of subscription IDs to load KeyVault resources from.

    .EXAMPLE
        Initialize-KeyVaultService -SubscriptionIds @('sub-id-1')
        $script:KeyVaultService['sub-id-1'].KeyVaults  # Access cached vaults
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string[]]$SubscriptionIds = @()
    )

    $ErrorActionPreference = 'Stop'

    # Initialize service hashtable keyed by subscription
    $script:KeyVaultService = @{}

    if (-not $SubscriptionIds -or $SubscriptionIds.Count -eq 0) {
        # Nothing to process - function ends naturally
    }
    else {
        $armApiBase = $script:Config.azure.endpoints.armApi

        foreach ($subscriptionId in $SubscriptionIds) {
            Write-CIEMLog -Severity DEBUG -Message "Loading KeyVault resources for subscription: $subscriptionId"

            $script:KeyVaultService[$subscriptionId] = @{
                KeyVaults          = @()
                DiagnosticSettings = @{}
                Keys               = @{}
                Secrets            = @{}
            }

            # Load Key Vaults
            $params = @{
                Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.KeyVault/vaults?api-version=2023-07-01"
                ResourceName = "KeyVaults ($subscriptionId)"
            }
            $vaults = Invoke-AzureApi @params

            if ($vaults) {
                $script:KeyVaultService[$subscriptionId].KeyVaults = $vaults

                foreach ($vault in $vaults) {
                    $vaultName = $vault.name

                    # Load Diagnostic Settings for each vault
                    $diagParams = @{
                        Uri          = "$armApiBase$($vault.id)/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
                        ResourceName = "DiagnosticSettings ($vaultName)"
                    }
                    $script:KeyVaultService[$subscriptionId].DiagnosticSettings[$vaultName] = Invoke-AzureApi @diagParams

                    # Try to load keys and secrets from data plane (requires vault access)
                    # Strict mode safe property access
                    $vaultUri = if ($vault.properties.PSObject.Properties['vaultUri']) {
                        $vault.properties.vaultUri
                    }
                    else {
                        $null
                    }
                    if ($vaultUri) {
                        $vaultUri = $vaultUri.TrimEnd('/')

                        # Load Keys and Secrets using data-driven pattern
                        $dataPlaneEndpoints = @{
                            Keys    = "$vaultUri/keys?api-version=7.4"
                            Secrets = "$vaultUri/secrets?api-version=7.4"
                        }

                        foreach ($dp in $dataPlaneEndpoints.GetEnumerator()) {
                            # Use SilentlyContinue because 403 is expected when SP lacks data plane access
                            $items = Invoke-AzureApi -Uri $dp.Value -Api KeyVault -ResourceName "$($dp.Key) ($vaultName)" -ErrorAction SilentlyContinue
                            if ($items) {
                                $script:KeyVaultService[$subscriptionId][$dp.Key][$vaultName] = $items
                            }
                            else {
                                Write-CIEMLog -Severity DEBUG -Message "Cannot access $($dp.Key.ToLower()) in vault $vaultName - data plane access denied or not available"
                            }
                        }
                    }
                }

                Write-CIEMLog -Severity DEBUG -Message "KeyVault loaded for $subscriptionId : $($vaults.Count) vaults"
            }
            else {
                Write-CIEMLog -Severity DEBUG -Message "No Key Vaults found in subscription $subscriptionId"
            }
        }
    }
}
