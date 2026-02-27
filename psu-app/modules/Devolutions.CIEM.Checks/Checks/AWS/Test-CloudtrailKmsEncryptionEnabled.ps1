function Test-CloudtrailKmsEncryptionEnabled {
    <#
    .SYNOPSIS
        CloudTrail trail logs are encrypted at rest with a KMS key

    .DESCRIPTION
        **AWS CloudTrail trails** are evaluated for use of **SSE-KMS** with a customer-managed KMS key to encrypt delivered log files at rest in S3. Trails without a configured KMS key are identified. *Applies to single-Region and multi-Region trails.*

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

    # TODO: Implement check logic based on Prowler check: cloudtrail_kms_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check cloudtrail_kms_encryption_enabled for reference.', 'N/A', 'cloudtrail Resources')
}
