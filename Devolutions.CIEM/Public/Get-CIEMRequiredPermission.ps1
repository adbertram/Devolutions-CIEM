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
            Summary           = "No checks found."
        }
    }
    else {
        # Aggregate unique permissions
        $graphPermissions = @()
        $armPermissions = @()
        $kvPermissions = @()

        foreach ($check in $checks) {
            # Use safe property access since not all checks have all permission types
            $perms = $check.permissions
            if ($perms.PSObject.Properties['graph'] -and $perms.graph) {
                $graphPermissions += $perms.graph
            }
            if ($perms.PSObject.Properties['arm'] -and $perms.arm) {
                $armPermissions += $perms.arm
            }
            if ($perms.PSObject.Properties['keyvaultDataPlane'] -and $perms.keyvaultDataPlane) {
                $kvPermissions += $perms.keyvaultDataPlane
            }
        }

        # Get unique and sort
        $graphPermissions = $graphPermissions | Select-Object -Unique | Sort-Object
        $armPermissions = $armPermissions | Select-Object -Unique | Sort-Object
        $kvPermissions = $kvPermissions | Select-Object -Unique | Sort-Object

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
            $summaryParts += ""
            $summaryParts += "  Tip: Assign the 'Reader' role at the subscription/management group level to cover most ARM permissions."
        }

        if ($kvPermissions.Count -gt 0) {
            $summaryParts += ""
            $summaryParts += "Key Vault Data Plane Permissions:"
            foreach ($perm in $kvPermissions) {
                $summaryParts += "  - $perm"
            }
            $summaryParts += ""
            $summaryParts += "  Tip: Assign 'Key Vault Reader' role and configure access policy or RBAC for data plane access."
        }

        [PSCustomObject]@{
            Graph             = @($graphPermissions)
            ARM               = @($armPermissions)
            KeyVaultDataPlane = @($kvPermissions)
            CheckCount        = $checks.Count
            Summary           = $summaryParts -join "`n"
        }
    }
}
