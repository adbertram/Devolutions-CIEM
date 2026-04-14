function Test-IamUserHardwareMfaEnabled {
    <#
    .SYNOPSIS
        IAM user has hardware MFA enabled

    .DESCRIPTION
        **IAM users** are evaluated for **hardware MFA** enrollment, identifying physical tokens or security keys and distinguishing them from *virtual* or *SMS* MFA, as well as users without any MFA.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: iam_user_hardware_mfa_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_user_hardware_mfa_enabled for reference.', 'N/A', 'iam Resources')
}
