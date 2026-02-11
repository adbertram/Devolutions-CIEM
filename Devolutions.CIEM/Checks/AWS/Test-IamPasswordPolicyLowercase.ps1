function Test-IamPasswordPolicyLowercase {
    <#
    .SYNOPSIS
        IAM password policy requires at least one lowercase letter

    .DESCRIPTION
        **IAM password policy** requires at least one **lowercase** character in user passwords via the `Require lowercase` setting

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: iam_password_policy_lowercase

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_password_policy_lowercase for reference.', 'N/A', 'iam Resources')
}
