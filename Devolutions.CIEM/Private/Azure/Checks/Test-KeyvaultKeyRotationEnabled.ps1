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
            $keys = $kvData.Keys[$vault.name]

            if ($null -eq $keys) {
                $params = @{
                    CheckMetadata  = $CheckMetadata
                    Status         = 'MANUAL'
                    StatusExtended = "Cannot access keys in vault '$($vault.name)' - data plane access denied. Manual verification required."
                    ResourceId     = $vault.id
                    ResourceName   = $vault.name
                    Location       = $vault.location
                }
                New-CIEMFinding @params
                continue
            }

            if ($keys.Count -eq 0) {
                $params = @{
                    CheckMetadata  = $CheckMetadata
                    Status         = 'PASS'
                    StatusExtended = "Vault '$($vault.name)' has no keys configured."
                    ResourceId     = $vault.id
                    ResourceName   = $vault.name
                    Location       = $vault.location
                }
                New-CIEMFinding @params
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
                    $params = @{
                        CheckMetadata  = $CheckMetadata
                        Status         = 'PASS'
                        StatusExtended = "Vault '$($vault.name)' has key '$keyName' with rotation policy set."
                        ResourceId     = $vault.id
                        ResourceName   = "$($vault.name)/$keyName"
                        Location       = $vault.location
                    }
                    New-CIEMFinding @params
                }
                else {
                    $params = @{
                        CheckMetadata  = $CheckMetadata
                        Status         = 'FAIL'
                        StatusExtended = "Vault '$($vault.name)' has key '$keyName' without rotation policy set."
                        ResourceId     = $vault.id
                        ResourceName   = "$($vault.name)/$keyName"
                        Location       = $vault.location
                    }
                    New-CIEMFinding @params
                }
            }
        }
    }
}
