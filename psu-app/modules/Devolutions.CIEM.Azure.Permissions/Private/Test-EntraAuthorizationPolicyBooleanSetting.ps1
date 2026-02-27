function Test-EntraAuthorizationPolicyBooleanSetting {
    <#
    .SYNOPSIS
        Tests a boolean setting in the Entra authorization policy defaultUserRolePermissions.

    .DESCRIPTION
        Parameterized helper function that checks boolean settings in the authorization
        policy's defaultUserRolePermissions. Used by multiple check functions that verify
        whether certain user actions are restricted.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .PARAMETER PropertyName
        Name of the property to check in defaultUserRolePermissions (e.g., 'allowedToCreateSecurityGroups').

    .PARAMETER PassMessage
        Message to display when the check passes (setting is false).

    .PARAMETER FailMessage
        Message to display when the check fails (setting is true or not set).

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$PassMessage,

        [Parameter(Mandatory)]
        [string]$FailMessage
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Entra' }).CacheData

    if (-not $svc.AuthorizationPolicy) {
        [CIEMScanResult]::Create($Check, 'SKIPPED', 'Unable to retrieve authorization policy - missing permissions', 'N/A', 'Authorization Policy')
    }
    else {
        # Authorization policy can be returned as an array, get the first item
        $authPolicy = if ($svc.AuthorizationPolicy -is [array]) {
            $svc.AuthorizationPolicy | Select-Object -First 1
        }
        else {
            $svc.AuthorizationPolicy
        }

        # Check the specified property setting
        $propertyValue = $authPolicy.defaultUserRolePermissions.$PropertyName

        if ($propertyValue -eq $false) {
            [CIEMScanResult]::Create($Check, 'PASS', $PassMessage, $authPolicy.id, 'Authorization Policy')
        }
        else {
            [CIEMScanResult]::Create($Check, 'FAIL', $FailMessage, $authPolicy.id, 'Authorization Policy')
        }
    }
}
