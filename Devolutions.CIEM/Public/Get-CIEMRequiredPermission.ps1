function Get-CIEMRequiredPermission {
    <#
    .SYNOPSIS
        Gets the required permissions for running CIEM security checks.

    .DESCRIPTION
        Aggregates all unique permissions required across all enabled checks.
        Returns permissions grouped by type: Microsoft Graph API permissions,
        Azure Resource Manager RBAC actions, and Key Vault data plane permissions.

    .PARAMETER Service
        Filter to permissions required for a specific service (Entra, IAM, KeyVault, Storage).

    .PARAMETER CheckId
        Filter to permissions required for specific check IDs.

    .OUTPUTS
        [PSCustomObject] Object containing:
        - Graph: Array of Microsoft Graph API permissions (e.g., "User.Read.All")
        - ARM: Array of Azure Resource Manager RBAC actions (e.g., "Microsoft.Storage/storageAccounts/read")
        - KeyVaultDataPlane: Array of Key Vault data plane permissions (e.g., "secrets/list")
        - AzureRoles: Array of Azure RBAC role names required to satisfy ARM and KeyVault permissions
        - Summary: Human-readable summary text

    .EXAMPLE
        Get-CIEMRequiredPermission
        # Returns all permissions required for all checks

    .EXAMPLE
        Get-CIEMRequiredPermission -Service Entra
        # Returns permissions required for Entra ID checks only

    .EXAMPLE
        Get-CIEMRequiredPermission -CheckId 'entra_security_defaults_enabled', 'entra_global_admin_in_less_than_five_users'
        # Returns permissions for specific checks
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet('Entra', 'IAM', 'KeyVault', 'Storage')]
        [string]$Service,

        [Parameter()]
        [string[]]$CheckId
    )

    $ErrorActionPreference = 'Stop'

    # Get checks based on filters
    $getCheckParams = @{}
    if ($Service) { $getCheckParams.Service = $Service }

    $checks = Get-CIEMCheck @getCheckParams

    if ($CheckId) {
        $checks = $checks | Where-Object { $CheckId -contains $_.id }
    }

    if (-not $checks) {
        Write-Warning "No checks found matching the specified criteria."
        [PSCustomObject]@{
            Graph             = @()
            ARM               = @()
            KeyVaultDataPlane = @()
            AzureRoles        = @()
            CheckCount        = 0
            Summary           = "No checks found."
        }
    }
    else {
        # Aggregate unique permissions using List for efficient collection
        $graphPermissions = [System.Collections.Generic.List[string]]::new()
        $armPermissions = [System.Collections.Generic.List[string]]::new()
        $kvPermissions = [System.Collections.Generic.List[string]]::new()

        foreach ($check in $checks) {
            # Use safe property access since not all checks have all permission types
            $perms = $check.permissions
            if ($perms.PSObject.Properties['graph'] -and $perms.graph) {
                foreach ($p in $perms.graph) { $graphPermissions.Add($p) }
            }
            if ($perms.PSObject.Properties['arm'] -and $perms.arm) {
                foreach ($p in $perms.arm) { $armPermissions.Add($p) }
            }
            if ($perms.PSObject.Properties['keyvaultDataPlane'] -and $perms.keyvaultDataPlane) {
                foreach ($p in $perms.keyvaultDataPlane) { $kvPermissions.Add($p) }
            }
        }

        # Get unique and sort (wrap in @() to ensure arrays)
        $graphPermissions = @($graphPermissions | Select-Object -Unique | Sort-Object)
        $armPermissions = @($armPermissions | Select-Object -Unique | Sort-Object)
        $kvPermissions = @($kvPermissions | Select-Object -Unique | Sort-Object)

        # Determine required Azure RBAC roles based on permissions
        $azureRoles = @()

        # ARM permissions: Reader role covers all */read actions
        if ($armPermissions.Count -gt 0) {
            # Check if all ARM permissions are read-only (end with /read or /*/read)
            $nonReadPermissions = @($armPermissions | Where-Object { $_ -notmatch '/read$' })
            if ($nonReadPermissions.Count -eq 0) {
                $azureRoles += 'Reader'
            }
            else {
                # Some write permissions detected - would need Contributor or custom role
                $azureRoles += 'Reader'  # Still include Reader for read permissions
                Write-Warning "Some ARM permissions require write access. Review permissions and assign appropriate roles."
            }
        }

        # Key Vault data plane permissions: Map to specific RBAC roles
        if ($kvPermissions -contains 'secrets/list' -or $kvPermissions -contains 'secrets/get') {
            $azureRoles += 'Key Vault Secrets User'
        }
        if ($kvPermissions -contains 'keys/list' -or $kvPermissions -contains 'keys/get') {
            $azureRoles += 'Key Vault Crypto User'
        }

        $azureRoles = @($azureRoles | Select-Object -Unique | Sort-Object)

        # Build summary
        $summaryParts = @()
        $summaryParts += "Permissions required for $($checks.Count) check(s):"

        if ($graphPermissions.Count -gt 0) {
            $summaryParts += ""
            $summaryParts += "Microsoft Graph API Permissions (Application):"
            foreach ($perm in $graphPermissions) {
                $summaryParts += "  - $perm"
            }
        }

        if ($armPermissions.Count -gt 0) {
            $summaryParts += ""
            $summaryParts += "Azure Resource Manager RBAC Actions:"
            foreach ($perm in $armPermissions) {
                $summaryParts += "  - $perm"
            }
        }

        if ($kvPermissions.Count -gt 0) {
            $summaryParts += ""
            $summaryParts += "Key Vault Data Plane Permissions:"
            foreach ($perm in $kvPermissions) {
                $summaryParts += "  - $perm"
            }
        }

        if ($azureRoles.Count -gt 0) {
            $summaryParts += ""
            $summaryParts += "Required Azure RBAC Roles:"
            foreach ($role in $azureRoles) {
                $summaryParts += "  - $role"
            }
        }

        [PSCustomObject]@{
            Graph             = @($graphPermissions)
            ARM               = @($armPermissions)
            KeyVaultDataPlane = @($kvPermissions)
            AzureRoles        = @($azureRoles)
            CheckCount        = $checks.Count
            Summary           = $summaryParts -join "`n"
        }
    }
}
