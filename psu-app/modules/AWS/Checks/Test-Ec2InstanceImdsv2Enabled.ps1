function Test-Ec2InstanceImdsv2Enabled {
    <#
    .SYNOPSIS
        EC2 instance requires IMDSv2 or has the instance metadata service disabled

    .DESCRIPTION
        **EC2 instances** are evaluated for **IMDSv2 enforcement**: metadata endpoint enabled with `http_tokens: required`, or metadata service fully disabled (`http_endpoint: disabled`).

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

    # TODO: Implement check logic based on Prowler check: ec2_instance_imdsv2_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_imdsv2_enabled for reference.', 'N/A', 'ec2 Resources')
}
