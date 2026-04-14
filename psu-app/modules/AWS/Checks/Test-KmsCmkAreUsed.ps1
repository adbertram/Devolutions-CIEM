function Test-KmsCmkAreUsed {
    <#
    .SYNOPSIS
        KMS customer managed key is enabled or scheduled for deletion

    .DESCRIPTION
        **Customer-managed KMS keys** are assessed by key state. Keys in `Enabled` are considered in use. Keys not `Enabled` and not `PendingDeletion` are identified as unused, while those in `PendingDeletion` are recognized as scheduled for removal.

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

    # TODO: Implement check logic based on Prowler check: kms_cmk_are_used

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check kms_cmk_are_used for reference.', 'N/A', 'kms Resources')
}
