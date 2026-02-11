function Test-IamRoleCrossAccountReadonlyaccessPolicy {
    <#
    .SYNOPSIS
        IAM role does not grant ReadOnlyAccess to external AWS accounts

    .DESCRIPTION
        **IAM roles** are assessed for the AWS-managed **ReadOnlyAccess** policy combined with a trust policy that allows **external AWS principals** or `*`. This identifies roles that expose broad read permissions to other accounts.

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

    # TODO: Implement check logic based on Prowler check: iam_role_cross_account_readonlyaccess_policy

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_role_cross_account_readonlyaccess_policy for reference.', 'N/A', 'iam Resources')
}
