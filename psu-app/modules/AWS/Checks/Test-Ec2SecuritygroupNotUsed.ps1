function Test-Ec2SecuritygroupNotUsed {
    <#
    .SYNOPSIS
        Non-default EC2 security group is in use

    .DESCRIPTION
        EC2 security groups, except `default`, are assessed for **unused** status: zero attached network interfaces, no AWS Lambda associations, and no references from other security groups.

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

    # TODO: Implement check logic based on Prowler check: ec2_securitygroup_not_used

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_securitygroup_not_used for reference.', 'N/A', 'ec2 Resources')
}
