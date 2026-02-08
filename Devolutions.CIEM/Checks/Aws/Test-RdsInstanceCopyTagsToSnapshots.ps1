function Test-RdsInstanceCopyTagsToSnapshots {
    <#
    .SYNOPSIS
        RDS DB instance has copy tags to snapshots enabled

    .DESCRIPTION
        **RDS DB instances** are assessed for propagating instance tags to their **DB snapshots** using `CopyTagsToSnapshot`.
        
        *Aurora engines manage this at the cluster level and aren't evaluated per instance.*

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

    # TODO: Implement check logic based on Prowler check: rds_instance_copy_tags_to_snapshots

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check rds_instance_copy_tags_to_snapshots for reference.', 'N/A', 'rds Resources')
}
