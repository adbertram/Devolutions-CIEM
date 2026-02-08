function Test-IamRotateAccessKey90Days {
    <#
    .SYNOPSIS
        IAM user does not have active access keys older than 90 days

    .DESCRIPTION
        **IAM user access keys** are assessed via the credential report. For each active key, the `last_rotated` timestamp is compared to `90 days`; keys exceeding this age are identified. Users without keys or with only recent rotations are noted.

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

    # TODO: Implement check logic based on Prowler check: iam_rotate_access_key_90_days

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_rotate_access_key_90_days for reference.', 'N/A', 'iam Resources')
}
