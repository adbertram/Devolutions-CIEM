function Test-EntraPolicyRestrictUserConsentForApp {
    <#
    .SYNOPSIS
        Tests if user consent for applications is properly restricted.

    .DESCRIPTION
        This check verifies that the authorization policy does not allow users to consent
        to applications accessing company data on their behalf. It checks for the presence
        of 'ManagePermissionGrantsForSelf' policies in defaultUserRolePermissions.

        When user consent is restricted, administrators must provide consent for applications
        before users can use them.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraPolicyRestrictsUserConsentForApps -CheckMetadata $metadata
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

        # Check if any policy allows user self-consent (ManagePermissionGrantsForSelf)
        $hasUserConsentPolicy = $false
        $userConsentPolicies = @()
        foreach ($policy in $permissionPolicies) {
            if ($policy -like 'ManagePermissionGrantsForSelf*') {
                $hasUserConsentPolicy = $true
                $userConsentPolicies += $policy
            }
        }

        if (-not $hasUserConsentPolicy) {
            $findingParams = @{
                CheckMetadata  = $CheckMetadata
                Status         = 'PASS'
                StatusExtended = 'Entra does not allow users to consent apps accessing company data on their behalf'
                ResourceId     = $authPolicy.id
                ResourceName   = 'Authorization Policy'
            }
            New-CIEMFinding @findingParams
        }
        else {
            $policyList = $userConsentPolicies -join ', '
            $findingParams = @{
                CheckMetadata  = $CheckMetadata
                Status         = 'FAIL'
                StatusExtended = "Entra allows users to consent apps accessing company data on their behalf. User consent policies: $policyList"
                ResourceId     = $authPolicy.id
                ResourceName   = 'Authorization Policy'
            }
            New-CIEMFinding @findingParams
        }
    }
}
