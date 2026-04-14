function Test-IamUserWithTemporaryCredentials {
    <#
    .SYNOPSIS
        IAM user does not use long-lived credentials to access services other than IAM or STS

    .DESCRIPTION
        IAM users are assessed for activity using **long-lived access keys**. Use of static credentials to access services other than IAM or STS indicates reliance on permanent keys instead of **temporary role-based credentials**.

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

    # TODO: Implement check logic based on Prowler check: iam_user_with_temporary_credentials

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_user_with_temporary_credentials for reference.', 'N/A', 'iam Resources')
}
