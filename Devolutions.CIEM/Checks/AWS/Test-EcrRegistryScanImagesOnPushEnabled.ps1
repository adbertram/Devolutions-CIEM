function Test-EcrRegistryScanImagesOnPushEnabled {
    <#
    .SYNOPSIS
        ECR registry has image scanning on push enabled for all repositories

    .DESCRIPTION
        Amazon ECR registries with repositories are evaluated for image scanning configured as `scan on push` at the registry level, with scan rules that cover all repositories (no restrictive filters), for either **basic** or **enhanced** scanning.

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

    # TODO: Implement check logic based on Prowler check: ecr_registry_scan_images_on_push_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ecr_registry_scan_images_on_push_enabled for reference.', 'N/A', 'ecr Resources')
}
