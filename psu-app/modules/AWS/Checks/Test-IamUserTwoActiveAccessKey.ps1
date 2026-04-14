function Test-IamUserTwoActiveAccessKey {
    <#
    .SYNOPSIS
        IAM user has at most one active access key

    .DESCRIPTION
        **IAM users** are evaluated for having **two `Active` access keys** simultaneously.
        
        The check identifies users whose two access key slots are enabled at the same time.

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

    # TODO: Implement check logic based on Prowler check: iam_user_two_active_access_key

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_user_two_active_access_key for reference.', 'N/A', 'iam Resources')
}
