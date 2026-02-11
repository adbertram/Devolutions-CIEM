function Test-IamRoleUserAccessAdminRestricted {
    <#
    .SYNOPSIS
        Tests if the User Access Administrator role is properly restricted.

    .DESCRIPTION
        Checks for active assignments of the highly privileged 'User Access Administrator'
        role in Azure subscriptions. Reports on each role assignment individually.

        The User Access Administrator role grants the ability to manage access to Azure
        resources, which can lead to privilege escalation if not properly restricted.

        Built-in User Access Administrator role ID: 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9

    .PARAMETER Check
        CIEMCheck object containing check metadata.
        - id: Check identifier
        - severity: Severity level

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects, one per role assignment.

    .NOTES
        Data source: $script:IAMService[$subscriptionId].RoleAssignments and RoleDefinitions
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # User Access Administrator built-in role definition ID
    $userAccessAdminRoleId = '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'

    foreach ($subscriptionId in $script:IAMService.Keys) {
        $iamData = $script:IAMService[$subscriptionId]

        # Check if role assignments were loaded
        if (-not $iamData.RoleAssignments) {
            [CIEMScanResult]::Create(
                $Check,
                'SKIPPED',
                "Unable to retrieve role assignments for subscription $subscriptionId",
                "/subscriptions/$subscriptionId",
                "Subscription $subscriptionId"
            )
            continue
        }

        $roleAssignments = $iamData.RoleAssignments
        $roleDefinitions = $iamData.RoleDefinitions

        # Build a lookup of role definition IDs to names
        $roleNameLookup = @{}
        if ($roleDefinitions) {
            foreach ($role in $roleDefinitions) {
                $roleId = if ($role.PSObject.Properties['name']) { $role.name } else { $null }
                $roleName = if ($role.properties.PSObject.Properties['roleName']) {
                    $role.properties.roleName
                }
                else {
                    $null
                }
                if ($roleId -and $roleName) {
                    $roleNameLookup[$roleId] = $roleName
                }
            }
        }

        # Report on each role assignment
        foreach ($assignment in $roleAssignments) {
            # Extract assignment details (strict mode safe)
            $assignmentName = if ($assignment.PSObject.Properties['name']) {
                $assignment.name
            }
            else {
                'Unknown'
            }

            $roleDefinitionId = if ($assignment.properties.PSObject.Properties['roleDefinitionId']) {
                $assignment.properties.roleDefinitionId
            }
            else {
                $null
            }

            $principalId = if ($assignment.properties.PSObject.Properties['principalId']) {
                $assignment.properties.principalId
            }
            else {
                'Unknown'
            }

            $principalType = if ($assignment.properties.PSObject.Properties['principalType']) {
                $assignment.properties.principalType
            }
            else {
                'Unknown'
            }

            # Extract the role GUID from the full resource ID
            $roleGuid = if ($roleDefinitionId -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
                $matches[0]
            }
            else {
                $null
            }

            # Look up the role name
            $roleName = if ($roleGuid -and $roleNameLookup.ContainsKey($roleGuid)) {
                $roleNameLookup[$roleGuid]
            }
            else {
                ''
            }

            # Check if this is the User Access Administrator role
            $isUserAccessAdmin = ($roleName -eq 'User Access Administrator') -or ($roleGuid -eq $userAccessAdminRoleId)

            if ($isUserAccessAdmin) {
                [CIEMScanResult]::Create(
                    $Check,
                    'FAIL',
                    "Role assignment $assignmentName in subscription $subscriptionId grants User Access Administrator role to $principalType $principalId.",
                    $assignment.id,
                    $assignmentName
                )
            }
            else {
                [CIEMScanResult]::Create(
                    $Check,
                    'PASS',
                    "Role assignment $assignmentName in subscription $subscriptionId does not grant User Access Administrator role.",
                    $assignment.id,
                    $assignmentName
                )
            }
        }
    }
}
