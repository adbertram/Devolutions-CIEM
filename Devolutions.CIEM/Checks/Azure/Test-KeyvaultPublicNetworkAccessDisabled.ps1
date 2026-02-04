function Test-KeyvaultPublicNetworkAccessDisabled {
    <#
    .SYNOPSIS
        Tests that public network access is disabled for Key Vaults using private endpoints.

    .DESCRIPTION
        Verifies that Key Vaults with private endpoints have public network access disabled.
        When using private endpoints, public network access should be disabled to ensure
        all traffic flows through the private connection.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata (id, service, title, severity).

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
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
            $hasPrivateEndpoints = $privateEndpoints -and $privateEndpoints.Count -gt 0

            $publicNetworkAccess = if ($vault.properties.PSObject.Properties['publicNetworkAccess']) {
                $vault.properties.publicNetworkAccess
            }
            else {
                $null
            }
            $networkDefaultAction = if ($vault.properties.PSObject.Properties['networkAcls'] -and $vault.properties.networkAcls.PSObject.Properties['defaultAction']) {
                $vault.properties.networkAcls.defaultAction
            }
            else {
                $null
            }
            $isPublicAccessDisabled = ($publicNetworkAccess -eq 'Disabled' -or $networkDefaultAction -eq 'Deny')

            $status = if ($isPublicAccessDisabled) { 'PASS' } else { 'FAIL' }

            $message = if ($hasPrivateEndpoints) {
                if ($isPublicAccessDisabled) {
                    $accessStatus = if ($publicNetworkAccess -eq 'Disabled') { 'publicNetworkAccess=Disabled' } else { 'networkAcls.defaultAction=Deny' }
                    "Vault '$($vault.name)' has private endpoints and public network access is disabled ($accessStatus)."
                }
                else {
                    "Vault '$($vault.name)' has private endpoints but public network access is still enabled. Disable public network access or set network ACLs default action to 'Deny'."
                }
            }
            else {
                if ($isPublicAccessDisabled) {
                    "Vault '$($vault.name)' does not have private endpoints but public network access is restricted."
                }
                else {
                    "Vault '$($vault.name)' has public network access enabled and no private endpoints. Consider using private endpoints and disabling public access."
                }
            }

            [CIEMScanResult]::Create($CheckMetadata, $status, $message, $vault.id, $vault.name, $vault.location)
        }
    }
}
