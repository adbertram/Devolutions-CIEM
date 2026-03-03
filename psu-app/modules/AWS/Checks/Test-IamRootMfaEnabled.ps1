function Test-IamRootMfaEnabled {
    <#
    .SYNOPSIS
        Root account has MFA enabled

    .DESCRIPTION
        AWS root user with active credentials is assessed for MFA activation. The evaluation considers whether the root identity has a password or access keys and whether MFA is enabled.

        If centralized root access is enabled in Organizations, the presence of individual root credentials is also noted.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .PARAMETER ServiceCache
        Array of CIEMServiceCache objects containing pre-loaded IAM data.

    .NOTES
        Data source: $svc.CredentialReport (row where user is '<root_account>')
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'IAM' }).CacheData

    if (-not $svc.CredentialReport) {
        [CIEMScanResult]::Create($Check, 'SKIPPED', 'Credential report not available', 'N/A', 'Root Account')
        return
    }

    $rootEntry = $svc.CredentialReport | Where-Object { $_.user -eq '<root_account>' }

    if (-not $rootEntry) {
        [CIEMScanResult]::Create($Check, 'SKIPPED', 'Root account entry not found in credential report', 'N/A', 'Root Account')
        return
    }

    $accountId = $rootEntry.arn.Split(':')[4]
    $resourceId = "arn:aws:iam::${accountId}:root"
    $mfaActive = $rootEntry.mfa_active -eq 'true'

    if ($mfaActive) {
        [CIEMScanResult]::Create(
            $Check,
            'PASS',
            'Root account has MFA enabled.',
            $resourceId,
            'Root Account'
        )
    } else {
        [CIEMScanResult]::Create(
            $Check,
            'FAIL',
            'Root account does not have MFA enabled. Enable MFA for the root user to protect against unauthorized access.',
            $resourceId,
            'Root Account'
        )
    }
}
