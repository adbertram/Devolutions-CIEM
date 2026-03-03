function Test-IamUserMfaEnabledConsoleAccess {
    <#
    .SYNOPSIS
        IAM user has MFA enabled for console access or no console password is set

    .DESCRIPTION
        IAM users that have a console password are expected to have multi-factor authentication enabled. The evaluation identifies users who can sign in to the AWS Management Console but do not have an active MFA device associated.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .PARAMETER ServiceCache
        Array of CIEMServiceCache objects containing pre-loaded IAM data.

    .NOTES
        Data source: $svc.CredentialReport (non-root users with password_enabled=true)
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
        [CIEMScanResult]::Create($Check, 'SKIPPED', 'Credential report not available', 'N/A', 'IAM Users')
        return
    }

    # Filter to non-root users with console password enabled
    $consoleUsers = @($svc.CredentialReport | Where-Object {
        $_.user -ne '<root_account>' -and $_.password_enabled -eq 'true'
    })

    if ($consoleUsers.Count -eq 0) {
        [CIEMScanResult]::Create(
            $Check,
            'PASS',
            'No IAM users with console access found.',
            'N/A',
            'IAM Users'
        )
        return
    }

    foreach ($user in $consoleUsers) {
        $mfaActive = $user.mfa_active -eq 'true'

        if ($mfaActive) {
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                "IAM user $($user.user) has MFA enabled for console access.",
                $user.arn,
                $user.user
            )
        } else {
            [CIEMScanResult]::Create(
                $Check,
                'FAIL',
                "IAM user $($user.user) has console access but MFA is not enabled. Enable MFA to secure console sign-in.",
                $user.arn,
                $user.user
            )
        }
    }
}
