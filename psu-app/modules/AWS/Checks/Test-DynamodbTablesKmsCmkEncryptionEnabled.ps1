function Test-DynamodbTablesKmsCmkEncryptionEnabled {
    <#
    .SYNOPSIS
        DynamoDB table is encrypted at rest with AWS KMS

    .DESCRIPTION
        **DynamoDB tables** use **AWS KMS keys** (`KMS`) for encryption at rest instead of the default service-owned key

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

    # TODO: Implement check logic based on Prowler check: dynamodb_tables_kms_cmk_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check dynamodb_tables_kms_cmk_encryption_enabled for reference.', 'N/A', 'dynamodb Resources')
}
