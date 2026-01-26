function Test-KeyVaultItemExpiration {
    <#
    .SYNOPSIS
        Tests that all items (keys or secrets) in Key Vaults have expiration dates set.

    .DESCRIPTION
        Parameterized helper function that checks expiration dates for keys or secrets
        in either RBAC or non-RBAC vaults. Used by the 4 specific check functions.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata (id, service, title, severity).

    .PARAMETER ItemType
        Type of item to check: 'Keys' or 'Secrets'.

    .PARAMETER RequireRbac
        If true, only check RBAC-enabled vaults. If false, only check non-RBAC vaults.

    .OUTPUTS
        [PSCustomObject[]] Array of finding objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata,

        [Parameter(Mandatory)]
        [ValidateSet('Keys', 'Secrets')]
        [string]$ItemType,

        [Parameter(Mandatory)]
        [bool]$RequireRbac
    )

    $ErrorActionPreference = 'Stop'

    $rbacLabel = if ($RequireRbac) { 'RBAC' } else { 'Non-RBAC' }
    $itemTypeLower = $ItemType.ToLower()
    $itemTypeSingular = $itemTypeLower.TrimEnd('s')

    foreach ($subscriptionId in $script:KeyVaultService.Keys) {
        $kvData = $script:KeyVaultService[$subscriptionId]

        foreach ($vault in $kvData.KeyVaults) {
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

            # Get items for this vault
            $items = $kvData.$ItemType[$vaultName]

            # If we couldn't access items (permissions issue), report as manual check
            if ($null -eq $items) {
                $params = @{
                    CheckMetadata  = $CheckMetadata
                    Status         = 'MANUAL'
                    StatusExtended = "Cannot access $itemTypeLower in $rbacLabel vault '$vaultName' - data plane access denied. Manual verification required."
                    ResourceId     = $resourceId
                    ResourceName   = $vaultName
                    Location       = $location
                }
                New-CIEMFinding @params
                continue
            }

            # If no items exist, vault passes by default
            if ($items.Count -eq 0) {
                $params = @{
                    CheckMetadata  = $CheckMetadata
                    Status         = 'PASS'
                    StatusExtended = "$rbacLabel vault '$vaultName' has no $itemTypeLower configured."
                    ResourceId     = $resourceId
                    ResourceName   = $vaultName
                    Location       = $location
                }
                New-CIEMFinding @params
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
                    $params = @{
                        CheckMetadata  = $CheckMetadata
                        Status         = 'FAIL'
                        StatusExtended = "Keyvault $vaultName has the $itemTypeSingular $itemName without expiration date set."
                        ResourceId     = $resourceId
                        ResourceName   = $vaultName
                        Location       = $location
                    }
                    New-CIEMFinding @params
                }
            }

            # Prowler: One PASS per vault if no items without expiration
            if (-not $hasItemWithoutExpiration) {
                $params = @{
                    CheckMetadata  = $CheckMetadata
                    Status         = 'PASS'
                    StatusExtended = "Keyvault $vaultName has all the $itemTypeLower with expiration date set."
                    ResourceId     = $resourceId
                    ResourceName   = $vaultName
                    Location       = $location
                }
                New-CIEMFinding @params
            }
        }
    }
}
