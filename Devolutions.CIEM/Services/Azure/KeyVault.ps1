[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$SubscriptionIds = @()
)

$ErrorActionPreference = 'Stop'

# Initialize service hashtable keyed by subscription
$data = @{}

if (-not $SubscriptionIds -or $SubscriptionIds.Count -eq 0) {
    # Nothing to process - script ends naturally
}
else {
    $armApiBase = (Get-CIEMProvider -Name 'Azure').Endpoints.armApi

    foreach ($subscriptionId in $SubscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading KeyVault resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
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
            $data[$subscriptionId].KeyVaults = $vaults

            foreach ($vault in $vaults) {
                $vaultName = $vault.name

                # Load Diagnostic Settings for each vault
                $diagParams = @{
                    Uri          = "$armApiBase$($vault.id)/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
                    ResourceName = "DiagnosticSettings ($vaultName)"
                }
                $data[$subscriptionId].DiagnosticSettings[$vaultName] = Invoke-AzureApi @diagParams

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
                            $data[$subscriptionId][$dp.Key][$vaultName] = $items
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

$data
