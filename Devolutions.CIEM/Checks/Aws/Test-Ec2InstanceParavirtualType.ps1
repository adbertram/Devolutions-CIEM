function Test-Ec2InstanceParavirtualType {
    <#
    .SYNOPSIS
        EC2 instance virtualization type is HVM

    .DESCRIPTION
        **EC2 instances** are evaluated for their virtualization mode. Instances with `virtualization_type` set to `paravirtual` are identified; those using **HVM** are recognized as hardware-assisted virtualization.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: ec2_instance_paravirtual_type

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_paravirtual_type for reference.', 'N/A', 'ec2 Resources')
}
