function Test-KeyvaultPrivateEndpoint {
    <#
    .SYNOPSIS
        Tests that Azure Key Vaults have private endpoints configured.

    .DESCRIPTION
        Verifies that Key Vaults are configured with private endpoint connections.
        Private endpoints keep network traffic limited to whitelisted resources and
        prevent exposure of vault data over the public internet.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata (id, service, title, severity).

    .OUTPUTS
        [PSCustomObject[]] Array of finding objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
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

                    $params = @{
                        CheckMetadata  = $CheckMetadata
                        Status         = 'PASS'
                        StatusExtended = "Vault '$($vault.name)' has $($approvedEndpoints.Count) approved private endpoint(s): $endpointNames"
                        ResourceId     = $vault.id
                        ResourceName   = $vault.name
                        Location       = $vault.location
                    }
                    New-CIEMFinding @params
                }
                else {
                    $params = @{
                        CheckMetadata  = $CheckMetadata
                        Status         = 'FAIL'
                        StatusExtended = "Vault '$($vault.name)' has private endpoint connection(s) but none are in 'Approved' state."
                        ResourceId     = $vault.id
                        ResourceName   = $vault.name
                        Location       = $vault.location
                    }
                    New-CIEMFinding @params
                }
            }
            else {
                $params = @{
                    CheckMetadata  = $CheckMetadata
                    Status         = 'FAIL'
                    StatusExtended = "Vault '$($vault.name)' does not have any private endpoints configured. Consider using private endpoints to secure network traffic."
                    ResourceId     = $vault.id
                    ResourceName   = $vault.name
                    Location       = $vault.location
                }
                New-CIEMFinding @params
            }
        }
    }
}
