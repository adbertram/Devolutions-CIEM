function Test-Ec2InstanceDetailedMonitoringEnabled {
    <#
    .SYNOPSIS
        EC2 instance has detailed monitoring enabled

    .DESCRIPTION
        **EC2 instances** are assessed for **CloudWatch detailed monitoring**, indicating whether 1-minute metrics collection is enabled.
        
        Instances lacking this setting provide only 5-minute metrics.

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

    # TODO: Implement check logic based on Prowler check: ec2_instance_detailed_monitoring_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_detailed_monitoring_enabled for reference.', 'N/A', 'ec2 Resources')
}
