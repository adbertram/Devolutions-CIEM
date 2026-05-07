function Test-EntraPolicyUserConsentForVerifiedApp {
    <#
    .SYNOPSIS
        Tests if user consent is limited to verified publisher applications.

    .DESCRIPTION
        This check verifies that the authorization policy does not include the legacy
        consent policy 'ManagePermissionGrantsForSelf.microsoft-user-default-legacy'
        which would allow users to consent to any application.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraPolicyUserConsentForVerifiedApps -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [object[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Entra' }).CacheData

    # Check if Authorization Policy data is available
    if (-not $svc.AuthorizationPolicy) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Unable to retrieve authorization policy - missing permissions',
            'N/A',
            'Authorization Policy'
        )
    }
    else {
        # Authorization policy can be returned as an array, get the first item
        $authPolicy = if ($svc.AuthorizationPolicy -is [array]) {
            $svc.AuthorizationPolicy | Select-Object -First 1
        }
        else {
            $svc.AuthorizationPolicy
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

        [CIEMScanResult]::Create($Check, $status, $statusExtended, $authPolicy.id, 'Authorization Policy')
    }
}
