function Test-Ec2InstanceManagedBySsm {
    <#
    .SYNOPSIS
        EC2 instance is managed by AWS Systems Manager or not running

    .DESCRIPTION
        **EC2 instances** are assessed for enrollment as **Systems Manager managed nodes**. Running instances lacking Systems Manager registration are marked as unmanaged; instances in `stopped`, `terminated`, or `pending` states are noted separately.

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

    # TODO: Implement check logic based on Prowler check: ec2_instance_managed_by_ssm

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_managed_by_ssm for reference.', 'N/A', 'ec2 Resources')
}
