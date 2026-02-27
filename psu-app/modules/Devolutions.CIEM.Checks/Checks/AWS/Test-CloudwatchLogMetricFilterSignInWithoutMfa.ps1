function Test-CloudwatchLogMetricFilterSignInWithoutMfa {
    <#
    .SYNOPSIS
        CloudWatch log metric filter and alarm exist for Management Console sign-in without MFA

    .DESCRIPTION
        **CloudTrail logs** in CloudWatch are assessed for a metric filter and alarm that detect console logins where `$.eventName = ConsoleLogin` and `$.additionalEventData.MFAUsed != \"Yes\"`.
        
        This reflects whether alerting exists for sign-ins that occur without **MFA**.

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

    # TODO: Implement check logic based on Prowler check: cloudwatch_log_metric_filter_sign_in_without_mfa

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check cloudwatch_log_metric_filter_sign_in_without_mfa for reference.', 'N/A', 'cloudwatch Resources')
}
