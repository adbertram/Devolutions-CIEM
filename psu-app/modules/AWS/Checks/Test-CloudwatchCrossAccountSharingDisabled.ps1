function Test-CloudwatchCrossAccountSharingDisabled {
    <#
    .SYNOPSIS
        CloudWatch does not allow cross-account sharing

    .DESCRIPTION
        **Amazon CloudWatch** cross-account sharing via the `CloudWatch-CrossAccountSharingRole` allows other AWS accounts to view your metrics, dashboards, and alarms. The presence of this role indicates that sharing is active.

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

    # TODO: Implement check logic based on Prowler check: cloudwatch_cross_account_sharing_disabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check cloudwatch_cross_account_sharing_disabled for reference.', 'N/A', 'cloudwatch Resources')
}
