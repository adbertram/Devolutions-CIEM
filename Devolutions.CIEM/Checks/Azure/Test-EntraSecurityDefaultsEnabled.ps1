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

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraSecurityDefaultsEnabled -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    if (-not $script:EntraService.SecurityDefaults) {
        [CIEMScanResult]::Create($Check, 'SKIPPED', 'Unable to retrieve Security Defaults policy - missing permissions', 'N/A', 'Security Defaults')
    }
    else {
        $securityDefaults = $script:EntraService.SecurityDefaults
        $isEnabled = $securityDefaults.isEnabled -eq $true

        if ($isEnabled) {
            [CIEMScanResult]::Create($Check, 'PASS', 'Entra security defaults is enabled.', $securityDefaults.id, 'Security Defaults')
        }
        else {
            [CIEMScanResult]::Create($Check, 'FAIL', 'Entra security defaults is disabled.', $securityDefaults.id, 'Security Defaults')
        }
    }
}
