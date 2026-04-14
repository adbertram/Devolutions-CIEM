function Test-Ec2InstanceProfileAttached {
    <#
    .SYNOPSIS
        EC2 instance is associated with an IAM instance profile role

    .DESCRIPTION
        **EC2 instances** are evaluated for association with an **IAM instance profile role** that delivers temporary credentials to workloads running on the instance

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

    # TODO: Implement check logic based on Prowler check: ec2_instance_profile_attached

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_profile_attached for reference.', 'N/A', 'ec2 Resources')
}
