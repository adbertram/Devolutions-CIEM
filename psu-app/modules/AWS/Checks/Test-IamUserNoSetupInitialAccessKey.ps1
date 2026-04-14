function Test-IamUserNoSetupInitialAccessKey {
    <#
    .SYNOPSIS
        IAM user does not have active access keys that have never been used

    .DESCRIPTION
        **IAM users** with a console password and active **access keys** that have `last_used` as `N/A` are identified.
        
        This highlights accounts where programmatic credentials exist but have never been exercised.

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

    # TODO: Implement check logic based on Prowler check: iam_user_no_setup_initial_access_key

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_user_no_setup_initial_access_key for reference.', 'N/A', 'iam Resources')
}
