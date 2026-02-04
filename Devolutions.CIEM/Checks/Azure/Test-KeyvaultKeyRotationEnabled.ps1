function Test-KeyvaultKeyRotationEnabled {
    <#
    .SYNOPSIS
        Tests that automatic key rotation is enabled for Key Vault keys.

    .DESCRIPTION
        Verifies that keys in Azure Key Vault have automatic rotation policies configured.
        Automatic key rotation removes the need for manual administration when keys expire
        and reduces the risk of using outdated cryptographic keys.

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
            $keys = $kvData.Keys[$vault.name]

            if ($null -eq $keys) {
                [CIEMScanResult]::Create($CheckMetadata, 'MANUAL', "Cannot access keys in vault '$($vault.name)' - data plane access denied. Manual verification required.", $vault.id, $vault.name, $vault.location)
                continue
            }

            if ($keys.Count -eq 0) {
                [CIEMScanResult]::Create($CheckMetadata, 'PASS', "Vault '$($vault.name)' has no keys configured.", $vault.id, $vault.name, $vault.location)
                continue
            }

            # Check each key for rotation policy (matches Prowler's logic)
            foreach ($key in $keys) {
                $keyName = ($key.kid -split '/')[-1]

                # Check if key has a rotation policy with "Rotate" action
                $hasRotationPolicy = $false
                if ($key.PSObject.Properties['rotationPolicy'] -and $key.rotationPolicy) {
                    $lifetimeActions = if ($key.rotationPolicy.PSObject.Properties['lifetimeActions']) {
                        $key.rotationPolicy.lifetimeActions
                    } else { @() }

                    foreach ($action in $lifetimeActions) {
                        $actionType = if ($action.PSObject.Properties['action'] -and $action.action.PSObject.Properties['type']) {
                            $action.action.type
                        } else { $null }

                        if ($actionType -eq 'Rotate') {
                            $hasRotationPolicy = $true
                            break
                        }
                    }
                }

                if ($hasRotationPolicy) {
                    [CIEMScanResult]::Create($CheckMetadata, 'PASS', "Vault '$($vault.name)' has key '$keyName' with rotation policy set.", $vault.id, "$($vault.name)/$keyName", $vault.location)
                }
                else {
                    [CIEMScanResult]::Create($CheckMetadata, 'FAIL', "Vault '$($vault.name)' has key '$keyName' without rotation policy set.", $vault.id, "$($vault.name)/$keyName", $vault.location)
                }
            }
        }
    }
}
