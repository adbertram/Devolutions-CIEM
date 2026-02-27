function Test-Ec2InstanceWithOutdatedAmi {
    <#
    .SYNOPSIS
        EC2 instance uses a non-deprecated Amazon AMI

    .DESCRIPTION
        **EC2 instances** launched from **Amazon-owned AMIs** are evaluated for the AMI's `DeprecationTime`; instances tied to images with a deprecation date in the past are reported as using **deprecated AMIs**.

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

    # TODO: Implement check logic based on Prowler check: ec2_instance_with_outdated_ami

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_with_outdated_ami for reference.', 'N/A', 'ec2 Resources')
}
