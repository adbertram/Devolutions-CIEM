function Test-Ec2InstanceOlderThanSpecificDays {
    <#
    .SYNOPSIS
        EC2 instance is not older than the configured maximum age or is not running

    .DESCRIPTION
        **EC2 instances** are evaluated for age while in `running` state. Instances launched beyond the configurable limit (`max_ec2_instance_age_in_days`, default `180`) are flagged as older than the allowed lifetime. Stopped instances are ignored.

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

    # TODO: Implement check logic based on Prowler check: ec2_instance_older_than_specific_days

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_older_than_specific_days for reference.', 'N/A', 'ec2 Resources')
}
