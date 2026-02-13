function Test-KeyVaultItemExpiration {
    <#
    .SYNOPSIS
        Tests that all items (keys or secrets) in Key Vaults have expiration dates set.

    .DESCRIPTION
        Parameterized helper function that checks expiration dates for keys or secrets
        in either RBAC or non-RBAC vaults. Used by the 4 specific check functions.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .PARAMETER ItemType
        Type of item to check: 'Keys' or 'Secrets'.

    .PARAMETER RequireRbac
        If true, only check RBAC-enabled vaults. If false, only check non-RBAC vaults.

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache,

        [Parameter(Mandatory)]
        [ValidateSet('Keys', 'Secrets')]
        [string]$ItemType,

        [Parameter(Mandatory)]
        [bool]$RequireRbac
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'KeyVault' }).CacheData

    $rbacLabel = if ($RequireRbac) { 'RBAC' } else { 'Non-RBAC' }
    $itemTypeLower = $ItemType.ToLower()
    $itemTypeSingular = $itemTypeLower.TrimEnd('s')

    # Track totals to emit a descriptive result when no vaults match the filter
    $totalVaults = 0
    $matchedVaults = 0

    foreach ($subscriptionId in $svc.Keys) {
        $kvData = $svc[$subscriptionId]

        foreach ($vault in $kvData.KeyVaults) {
            $totalVaults++
            $vaultName = $vault.name
            $location = $vault.location
            $resourceId = $vault.id
            # Strict mode safe property access
            $isRbacEnabled = if ($vault.properties.PSObject.Properties['enableRbacAuthorization']) {
                $vault.properties.enableRbacAuthorization -eq $true
            }
            else {
                $false
            }

            # Skip vaults that don't match the RBAC requirement
            if ($RequireRbac -and -not $isRbacEnabled) { continue }
            if (-not $RequireRbac -and $isRbacEnabled) { continue }

            $matchedVaults++

            # Get items for this vault
            $items = $kvData.$ItemType[$vaultName]

            # If we couldn't access items (permissions issue), report as manual check
            if ($null -eq $items) {
                [CIEMScanResult]::Create($Check, 'MANUAL', "Cannot access $itemTypeLower in $rbacLabel vault '$vaultName' - data plane access denied. Manual verification required.", $resourceId, $vaultName, $location)
                continue
            }

            # If no items exist, vault passes by default
            if ($items.Count -eq 0) {
                [CIEMScanResult]::Create($Check, 'PASS', "$rbacLabel vault '$vaultName' has no $itemTypeLower configured.", $resourceId, $vaultName, $location)
                continue
            }

            # Check each item for expiration (Prowler reports per-item FAIL, per-vault PASS)
            $hasItemWithoutExpiration = $false

            foreach ($item in $items) {
                # Keys use 'kid', secrets use 'id' for the identifier
                $idProperty = if ($ItemType -eq 'Keys') { 'kid' } else { 'id' }
                $itemName = ($item.$idProperty -split '/')[-1]

                # Check if item is enabled (Prowler only checks enabled items)
                $isEnabled = if ($item.PSObject.Properties['attributes'] -and
                    $item.attributes.PSObject.Properties['enabled']) {
                    $item.attributes.enabled -eq $true
                }
                else {
                    $true  # Default to enabled if property missing
                }

                # Strict mode safe: check if attributes.exp property exists (Prowler uses 'expires')
                $hasExpiration = $item.PSObject.Properties['attributes'] -and
                    $item.attributes.PSObject.Properties['exp'] -and
                    $null -ne $item.attributes.exp

                # Prowler: if not expires and enabled -> FAIL
                if (-not $hasExpiration -and $isEnabled) {
                    $hasItemWithoutExpiration = $true
                    [CIEMScanResult]::Create($Check, 'FAIL', "Keyvault $vaultName has the $itemTypeSingular $itemName without expiration date set.", $resourceId, $vaultName, $location)
                }
            }

            # Prowler: One PASS per vault if no items without expiration
            if (-not $hasItemWithoutExpiration) {
                [CIEMScanResult]::Create($Check, 'PASS', "Keyvault $vaultName has all the $itemTypeLower with expiration date set.", $resourceId, $vaultName, $location)
            }
        }
    }

    # Emit a descriptive SKIPPED when no vaults matched the RBAC filter (not applicable, not a pass)
    $oppositeLabel = if ($RequireRbac) { 'non-RBAC' } else { 'RBAC' }
    if ($matchedVaults -eq 0) {
        if ($totalVaults -eq 0) {
            [CIEMScanResult]::Create($Check, 'SKIPPED', "No Key Vaults found in any accessible subscription. This check is not applicable.", 'N/A', 'N/A')
        }
        else {
            # All vaults use the opposite authorization model
            [CIEMScanResult]::Create($Check, 'SKIPPED', "No $rbacLabel Key Vaults found - all $totalVaults vault(s) use $oppositeLabel authorization. This check is not applicable.", 'N/A', 'N/A')
        }
    }
}
