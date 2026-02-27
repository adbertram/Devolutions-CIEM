function Test-RdsInstanceProtectedByBackupPlan {
    <#
    .SYNOPSIS
        RDS instance is protected by an AWS Backup plan

    .DESCRIPTION
        **RDS DB instances** (non-Aurora) are included in an **AWS Backup plan**, indicating scheduled backups and retention are applied to the resource.
        
        *Aurora engines are evaluated separately.*

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

    # TODO: Implement check logic based on Prowler check: rds_instance_protected_by_backup_plan

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check rds_instance_protected_by_backup_plan for reference.', 'N/A', 'rds Resources')
}
