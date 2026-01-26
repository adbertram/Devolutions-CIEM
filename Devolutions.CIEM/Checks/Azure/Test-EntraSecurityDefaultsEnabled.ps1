function Test-EntraSecurityDefaultsEnabled {
    <#
    .SYNOPSIS
        Tests if Security Defaults is enabled in Microsoft Entra ID.

    .DESCRIPTION
        This check verifies that Security Defaults is enabled. Security Defaults provide
        a basic level of security including:
        - Requiring all users and admins to register for MFA
        - Challenging users with MFA when necessary
        - Disabling legacy authentication clients

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraSecurityDefaultsEnabled -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    if (-not $script:EntraService.SecurityDefaults) {
        $params = @{
            CheckMetadata  = $CheckMetadata
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve Security Defaults policy - missing permissions'
            ResourceId     = 'N/A'
            ResourceName   = 'Security Defaults'
        }
        New-CIEMFinding @params
    }
    else {
        $securityDefaults = $script:EntraService.SecurityDefaults
        $isEnabled = $securityDefaults.isEnabled -eq $true

        if ($isEnabled) {
            $params = @{
                CheckMetadata  = $CheckMetadata
                Status         = 'PASS'
                StatusExtended = 'Entra security defaults is enabled.'
                ResourceId     = $securityDefaults.id
                ResourceName   = 'Security Defaults'
            }
            New-CIEMFinding @params
        }
        else {
            $params = @{
                CheckMetadata  = $CheckMetadata
                Status         = 'FAIL'
                StatusExtended = 'Entra security defaults is disabled.'
                ResourceId     = $securityDefaults.id
                ResourceName   = 'Security Defaults'
            }
            New-CIEMFinding @params
        }
    }
}
