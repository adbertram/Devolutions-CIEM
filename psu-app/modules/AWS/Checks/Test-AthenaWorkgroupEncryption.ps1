function Test-AthenaWorkgroupEncryption {
    <#
    .SYNOPSIS
        Athena workgroup encrypts query results in S3 with server-side encryption

    .DESCRIPTION
        **Athena workgroups** are evaluated for **encryption of query results** to confirm result data is stored encrypted at rest, whether saved in Amazon S3 or via managed query results

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

    # TODO: Implement check logic based on Prowler check: athena_workgroup_encryption

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check athena_workgroup_encryption for reference.', 'N/A', 'athena Resources')
}
