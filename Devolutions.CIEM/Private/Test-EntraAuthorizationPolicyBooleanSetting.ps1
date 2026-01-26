function Test-EntraAuthorizationPolicyBooleanSetting {
    <#
    .SYNOPSIS
        Tests a boolean setting in the Entra authorization policy defaultUserRolePermissions.

    .DESCRIPTION
        Parameterized helper function that checks boolean settings in the authorization
        policy's defaultUserRolePermissions. Used by multiple check functions that verify
        whether certain user actions are restricted.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata (id, service, title, severity).

    .PARAMETER PropertyName
        Name of the property to check in defaultUserRolePermissions (e.g., 'allowedToCreateSecurityGroups').

    .PARAMETER PassMessage
        Message to display when the check passes (setting is false).

    .PARAMETER FailMessage
        Message to display when the check fails (setting is true or not set).

    .OUTPUTS
        [PSCustomObject[]] Array of finding objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$PassMessage,

        [Parameter(Mandatory)]
        [string]$FailMessage
    )

    $ErrorActionPreference = 'Stop'

    if (-not $script:EntraService.AuthorizationPolicy) {
        $params = @{
            CheckMetadata  = $CheckMetadata
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve authorization policy - missing permissions'
            ResourceId     = 'N/A'
            ResourceName   = 'Authorization Policy'
        }
        New-CIEMFinding @params
    }
    else {
        # Authorization policy can be returned as an array, get the first item
        $authPolicy = if ($script:EntraService.AuthorizationPolicy -is [array]) {
            $script:EntraService.AuthorizationPolicy | Select-Object -First 1
        }
        else {
            $script:EntraService.AuthorizationPolicy
        }

        # Check the specified property setting
        $propertyValue = $authPolicy.defaultUserRolePermissions.$PropertyName

        if ($propertyValue -eq $false) {
            $params = @{
                CheckMetadata  = $CheckMetadata
                Status         = 'PASS'
                StatusExtended = $PassMessage
                ResourceId     = $authPolicy.id
                ResourceName   = 'Authorization Policy'
            }
            New-CIEMFinding @params
        }
        else {
            $params = @{
                CheckMetadata  = $CheckMetadata
                Status         = 'FAIL'
                StatusExtended = $FailMessage
                ResourceId     = $authPolicy.id
                ResourceName   = 'Authorization Policy'
            }
            New-CIEMFinding @params
        }
    }
}
