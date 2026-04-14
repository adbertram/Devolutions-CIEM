function Test-StorageEnsureSoftDeleteIsEnabled {
    <#
    .SYNOPSIS
        Storage account has soft delete for containers enabled

    .DESCRIPTION
        **Azure Storage accounts** have **container soft delete** enabled via a retention policy that keeps deleted containers for a set period.

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

    # TODO: Implement check logic based on Prowler check: storage_ensure_soft_delete_is_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check storage_ensure_soft_delete_is_enabled for reference.', 'N/A', 'storage Resources')
}
