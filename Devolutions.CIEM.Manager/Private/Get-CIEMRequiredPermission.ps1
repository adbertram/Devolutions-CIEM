function Get-CIEMRequiredPermission {
    <#
    .SYNOPSIS
        Gets the required permissions for running CIEM security checks.

    .DESCRIPTION
        Aggregates all unique permissions required across all enabled checks.
        Returns permissions grouped by type: Microsoft Graph API permissions,
        Azure Resource Manager RBAC actions, and Key Vault data plane permissions.

        This is a private copy for the Manager module that calls the local
        private Get-CIEMCheck (no dependency on the CIEM module).

    .PARAMETER Service
        Filter to permissions required for a specific service (Entra, IAM, KeyVault, Storage).

    .PARAMETER CheckId
        Filter to permissions required for specific check IDs.

    .OUTPUTS
        [PSCustomObject] Object containing:
        - Graph: Array of Microsoft Graph API permissions
        - ARM: Array of Azure Resource Manager RBAC actions
        - KeyVaultDataPlane: Array of Key Vault data plane permissions
        - AzureRoles: Array of Azure RBAC role names required
        - Summary: Human-readable summary text
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
        $checks = $checks | Where-Object { $CheckId -contains $_.Id }
    }

    if (-not $checks) {
        Write-Warning "No checks found matching the specified criteria."
        return [PSCustomObject]@{
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
            $perms = $check.Permissions
            if ($perms.Graph) {
                foreach ($p in $perms.Graph) { $graphPermissions.Add($p) }
            }
            if ($perms.ARM) {
                foreach ($p in $perms.ARM) { $armPermissions.Add($p) }
            }
            if ($perms.KeyVaultDataPlane) {
                foreach ($p in $perms.KeyVaultDataPlane) { $kvPermissions.Add($p) }
            }
        }

        # Get unique and sort (wrap in @() to ensure arrays)
        $graphPermissions = @($graphPermissions | Select-Object -Unique | Sort-Object)
        $armPermissions = @($armPermissions | Select-Object -Unique | Sort-Object)
        $kvPermissions = @($kvPermissions | Select-Object -Unique | Sort-Object)

        # Determine required Azure RBAC roles based on permissions
        # Reader is always required for subscription discovery (Get-AzSubscription) and read actions
        $azureRoles = @('Reader')

        # Warn if any ARM permissions require write access (Reader won't cover them)
        if ($armPermissions.Count -gt 0) {
            $nonReadPermissions = @($armPermissions | Where-Object { $_ -notmatch '/read$' })
            if ($nonReadPermissions.Count -gt 0) {
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
            $summaryParts += "Required Azure RBAC Roles (assign at subscription scope):"
            $summaryParts += "  - Reader (required for subscription discovery)"
            foreach ($role in @($azureRoles | Where-Object { $_ -ne 'Reader' })) {
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
