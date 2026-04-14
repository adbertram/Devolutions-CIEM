function Test-FsxFileSystemCopyTagsToVolumesEnabled {
    <#
    .SYNOPSIS
        FSx file system has copy tags to volumes enabled

    .DESCRIPTION
        **Amazon FSx file systems** are configured to **copy tags to volumes** via `copy_tags_to_volumes`.
        
        Identifies file systems where volume resources will not inherit the file system's tags.

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

    # TODO: Implement check logic based on Prowler check: fsx_file_system_copy_tags_to_volumes_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check fsx_file_system_copy_tags_to_volumes_enabled for reference.', 'N/A', 'fsx Resources')
}
