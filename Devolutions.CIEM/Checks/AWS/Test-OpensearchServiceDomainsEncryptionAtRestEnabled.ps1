function Test-OpensearchServiceDomainsEncryptionAtRestEnabled {
    <#
    .SYNOPSIS
        Amazon OpenSearch Service domain has encryption at rest enabled

    .DESCRIPTION
        **Amazon OpenSearch Service domains** are evaluated for `encryption at rest` using AWS KMS (`AES-256`) across stored data, including indexes, swap files, and automated snapshots.

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

    # TODO: Implement check logic based on Prowler check: opensearch_service_domains_encryption_at_rest_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check opensearch_service_domains_encryption_at_rest_enabled for reference.', 'N/A', 'opensearch Resources')
}
