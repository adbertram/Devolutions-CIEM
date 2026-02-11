function Test-GlueDataCatalogsMetadataEncryptionEnabled {
    <#
    .SYNOPSIS
        Glue Data Catalog metadata is encrypted with KMS

    .DESCRIPTION
        **AWS Glue Data Catalog** metadata is encrypted at rest when catalog settings use **SSE-KMS** with a KMS key.
        
        Catalogs that do not configure `SSE-KMS` for metadata are considered unencrypted.

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

    # TODO: Implement check logic based on Prowler check: glue_data_catalogs_metadata_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check glue_data_catalogs_metadata_encryption_enabled for reference.', 'N/A', 'glue Resources')
}
