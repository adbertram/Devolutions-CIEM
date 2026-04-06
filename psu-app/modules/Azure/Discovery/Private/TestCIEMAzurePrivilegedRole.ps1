function TestCIEMAzurePrivilegedRole {
    <#
    .SYNOPSIS
        Determines if a role is privileged based on its name and/or permissions.
    .DESCRIPTION
        Checks against a list of known privileged Azure RBAC and Entra directory role names,
        plus inspects permissions JSON for wildcard or authorization-write actions.
    .PARAMETER RoleName
        The display name of the role.
    .PARAMETER PermissionsJson
        Optional JSON string of the role's permissions array (from role definition).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$RoleName,

        [Parameter()]
        [string]$PermissionsJson
    )

    $ErrorActionPreference = 'Stop'

    if ($RoleName -in $script:PrivilegedRoleNames) {
        return $true
    }

    # Check permissions JSON for dangerous actions
    if ($PermissionsJson) {
        $permissions = $PermissionsJson | ConvertFrom-Json
        if ($permissions) {
            foreach ($perm in $permissions) {
                $actions = @($perm.actions)
                foreach ($action in $actions) {
                    # Wildcard full access
                    if ($action -eq '*') { return $true }
                    # Authorization write (can grant roles)
                    if ($action -match '^Microsoft\.Authorization/\*$') { return $true }
                    if ($action -match '^Microsoft\.Authorization/roleAssignments/write$') { return $true }
                }
            }
        }
    }

    return $false
}
