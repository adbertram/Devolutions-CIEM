function Test-EntraGlobalAdminInLessThanFiveUsers {
    <#
    .SYNOPSIS
        Tests if fewer than 5 users have global administrator assignment.

    .DESCRIPTION
        This check verifies that the organization has fewer than 5 users assigned to
        the Global Administrator role to limit the attack surface.

        Global Administrator role template ID: 62e90394-69f5-4237-9190-012177145e10

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraGlobalAdminInLessThanFiveUsers -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'
    $globalAdminRoleTemplateId = '62e90394-69f5-4237-9190-012177145e10'

    # Check if Directory Roles data is available
    if (-not $script:EntraService.DirectoryRoles) {
        [PSCustomObject]@{
            CheckId        = $CheckMetadata.id
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve directory roles - missing permissions'
            ResourceId     = 'N/A'
            ResourceName   = 'Directory Roles'
            Location       = 'Global'
            Severity       = $CheckMetadata.severity
        }
    }
    else {
        # Find the Global Administrator role
        $globalAdminRole = $script:EntraService.DirectoryRoles | Where-Object { $_.roleTemplateId -eq $globalAdminRoleTemplateId }

        if (-not $globalAdminRole) {
            # Role might not be activated if no users are assigned - no finding to report
            return
        }
        else {
            # Get members of the Global Administrator role
            $globalAdminMembers = $script:EntraService.DirectoryRoleMembers[$globalAdminRole.id]
            $memberCount = if ($globalAdminMembers) { $globalAdminMembers.Count } else { 0 }

            if ($memberCount -lt 5) {
                [PSCustomObject]@{
                    CheckId        = $CheckMetadata.id
                    Status         = 'PASS'
                    StatusExtended = "There are $memberCount global administrators."
                    ResourceId     = $globalAdminRole.id
                    ResourceName   = 'Global Administrator'
                    Location       = 'Global'
                    Severity       = $CheckMetadata.severity
                }
            }
            else {
                [PSCustomObject]@{
                    CheckId        = $CheckMetadata.id
                    Status         = 'FAIL'
                    StatusExtended = "There are $memberCount global administrators. It should be less than five."
                    ResourceId     = $globalAdminRole.id
                    ResourceName   = 'Global Administrator'
                    Location       = 'Global'
                    Severity       = $CheckMetadata.severity
                }
            }
        }
    }
}
