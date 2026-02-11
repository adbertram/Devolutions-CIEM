function Test-KeyvaultPrivateEndpoint {
    <#
    .SYNOPSIS
        Tests that Azure Key Vaults have private endpoints configured.

    .DESCRIPTION
        Verifies that Key Vaults are configured with private endpoint connections.
        Private endpoints keep network traffic limited to whitelisted resources and
        prevent exposure of vault data over the public internet.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    foreach ($subscriptionId in $script:KeyVaultService.Keys) {
        $kvData = $script:KeyVaultService[$subscriptionId]

        foreach ($vault in $kvData.KeyVaults) {
            # Strict mode safe property access
            $privateEndpoints = if ($vault.properties.PSObject.Properties['privateEndpointConnections']) {
                $vault.properties.privateEndpointConnections
            }
            else {
                $null
            }

            if ($privateEndpoints -and $privateEndpoints.Count -gt 0) {
                $approvedEndpoints = $privateEndpoints | Where-Object {
                    $_.properties.privateLinkServiceConnectionState.status -eq 'Approved'
                }

                if ($approvedEndpoints.Count -gt 0) {
                    $endpointNames = ($approvedEndpoints | ForEach-Object {
                        ($_.properties.privateEndpoint.id -split '/')[-1]
                    }) -join ', '

                    [CIEMScanResult]::Create($Check, 'PASS', "Vault '$($vault.name)' has $($approvedEndpoints.Count) approved private endpoint(s): $endpointNames", $vault.id, $vault.name, $vault.location)
                }
                else {
                    [CIEMScanResult]::Create($Check, 'FAIL', "Vault '$($vault.name)' has private endpoint connection(s) but none are in 'Approved' state.", $vault.id, $vault.name, $vault.location)
                }
            }
            else {
                [CIEMScanResult]::Create($Check, 'FAIL', "Vault '$($vault.name)' does not have any private endpoints configured. Consider using private endpoints to secure network traffic.", $vault.id, $vault.name, $vault.location)
            }
        }
    }
}
