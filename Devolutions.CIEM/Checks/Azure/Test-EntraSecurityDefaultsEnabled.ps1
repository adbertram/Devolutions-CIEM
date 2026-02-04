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
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    if (-not $script:EntraService.SecurityDefaults) {
        [CIEMScanResult]::Create($CheckMetadata, 'SKIPPED', 'Unable to retrieve Security Defaults policy - missing permissions', 'N/A', 'Security Defaults')
    }
    else {
        $securityDefaults = $script:EntraService.SecurityDefaults
        $isEnabled = $securityDefaults.isEnabled -eq $true

        if ($isEnabled) {
            [CIEMScanResult]::Create($CheckMetadata, 'PASS', 'Entra security defaults is enabled.', $securityDefaults.id, 'Security Defaults')
        }
        else {
            [CIEMScanResult]::Create($CheckMetadata, 'FAIL', 'Entra security defaults is disabled.', $securityDefaults.id, 'Security Defaults')
        }
    }
}
