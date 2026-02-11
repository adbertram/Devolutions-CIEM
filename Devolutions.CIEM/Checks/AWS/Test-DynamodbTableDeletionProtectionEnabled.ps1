function Test-DynamodbTableDeletionProtectionEnabled {
    <#
    .SYNOPSIS
        DynamoDB table has deletion protection enabled

    .DESCRIPTION
        **DynamoDB tables** have **deletion protection** enabled via the `deletion protection` setting, meaning delete operations require this setting to be disabled first

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

    # TODO: Implement check logic based on Prowler check: dynamodb_table_deletion_protection_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check dynamodb_table_deletion_protection_enabled for reference.', 'N/A', 'dynamodb Resources')
}
