function Test-EfsEncryptionAtRestEnabled {
    <#
    .SYNOPSIS
        EFS file system has encryption at rest enabled

    .DESCRIPTION
        **Amazon EFS file system** has **encryption at rest** enabled using AWS KMS to protect file data and metadata stored on the service

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

    # TODO: Implement check logic based on Prowler check: efs_encryption_at_rest_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check efs_encryption_at_rest_enabled for reference.', 'N/A', 'efs Resources')
}
