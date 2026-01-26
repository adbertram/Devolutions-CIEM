function Test-EntraPolicyUserConsentForVerifiedApp {
    <#
    .SYNOPSIS
        Tests if user consent is limited to verified publisher applications.

    .DESCRIPTION
        This check verifies that the authorization policy does not include the legacy
        consent policy 'ManagePermissionGrantsForSelf.microsoft-user-default-legacy'
        which would allow users to consent to any application.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraPolicyUserConsentForVerifiedApps -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    # Check if Authorization Policy data is available
    if (-not $script:EntraService.AuthorizationPolicy) {
        $findingParams = @{
            CheckMetadata  = $CheckMetadata
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve authorization policy - missing permissions'
            ResourceId     = 'N/A'
            ResourceName   = 'Authorization Policy'
        }
        New-CIEMFinding @findingParams
    }
    else {
        # Authorization policy can be returned as an array, get the first item
        $authPolicy = if ($script:EntraService.AuthorizationPolicy -is [array]) {
            $script:EntraService.AuthorizationPolicy | Select-Object -First 1
        }
        else {
            $script:EntraService.AuthorizationPolicy
        }

        # Get defaultUserRolePermissions (strict mode safe)
        $defaultUserRolePermissions = if ($authPolicy.PSObject.Properties['defaultUserRolePermissions']) {
            $authPolicy.defaultUserRolePermissions
        }
        else {
            $null
        }

        # Get permission grant policies assigned (strict mode safe)
        $permissionPolicies = if ($defaultUserRolePermissions -and $defaultUserRolePermissions.PSObject.Properties['permissionGrantPoliciesAssigned']) {
            $defaultUserRolePermissions.permissionGrantPoliciesAssigned
        }
        else {
            @()
        }

        # Default to PASS
        $status = 'PASS'
        $statusExtended = 'Entra does not allow users to consent non-verified apps accessing company data on their behalf.'

        # Check if legacy policy exists
        $legacyPolicyName = 'ManagePermissionGrantsForSelf.microsoft-user-default-legacy'
        foreach ($policy in $permissionPolicies) {
            if ($policy -like "*$legacyPolicyName*") {
                $status = 'FAIL'
                $statusExtended = 'Entra allows users to consent apps accessing company data on their behalf.'
                break
            }
        }

        $findingParams = @{
            CheckMetadata  = $CheckMetadata
            Status         = $status
            StatusExtended = $statusExtended
            ResourceId     = $authPolicy.id
            ResourceName   = 'Authorization Policy'
        }
        New-CIEMFinding @findingParams
    }
}
