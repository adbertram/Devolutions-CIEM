function Test-Ec2EbsVolumeProtectedByBackupPlan {
    <#
    .SYNOPSIS
        EBS volume is protected by a backup plan

    .DESCRIPTION
        **EBS volumes** are evaluated for coverage by an **AWS Backup plan**, whether explicitly targeted or included via broad resource selection, confirming scheduled, policy-driven backups exist for the volume.

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

    # TODO: Implement check logic based on Prowler check: ec2_ebs_volume_protected_by_backup_plan

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_ebs_volume_protected_by_backup_plan for reference.', 'N/A', 'ec2 Resources')
}
