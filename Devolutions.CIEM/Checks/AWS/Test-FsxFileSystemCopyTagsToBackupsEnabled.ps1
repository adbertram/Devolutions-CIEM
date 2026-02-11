function Test-FsxFileSystemCopyTagsToBackupsEnabled {
    <#
    .SYNOPSIS
        FSx file system has copy tags to backups enabled

    .DESCRIPTION
        **Amazon FSx file systems** are evaluated for whether they copy **resource tags** to their **backups** via the `copy_tags_to_backups` setting.

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

    # TODO: Implement check logic based on Prowler check: fsx_file_system_copy_tags_to_backups_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check fsx_file_system_copy_tags_to_backups_enabled for reference.', 'N/A', 'fsx Resources')
}
