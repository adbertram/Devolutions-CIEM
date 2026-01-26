function New-CIEMFinding {
    <#
    .SYNOPSIS
        Creates a standardized CIEM finding object.

    .DESCRIPTION
        Helper function to create consistent finding objects used by all check functions.
        Reduces boilerplate and ensures consistent output format.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .PARAMETER Status
        Finding status: PASS, FAIL, MANUAL, or SKIPPED.

    .PARAMETER StatusExtended
        Detailed explanation of the finding.

    .PARAMETER ResourceId
        Azure resource ID or identifier.

    .PARAMETER ResourceName
        Resource display name.

    .PARAMETER Location
        Resource location. Defaults to 'Global'.

    .EXAMPLE
        $params = @{
            CheckMetadata  = $CheckMetadata
            Status         = 'PASS'
            StatusExtended = 'Check passed'
            ResourceId     = $vault.id
            ResourceName   = $vault.name
            Location       = $vault.location
        }
        New-CIEMFinding @params
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata,

        [Parameter(Mandatory)]
        [ValidateSet('PASS', 'FAIL', 'MANUAL', 'SKIPPED')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$StatusExtended,

        [Parameter(Mandatory)]
        [string]$ResourceId,

        [Parameter(Mandatory)]
        [string]$ResourceName,

        [Parameter()]
        [string]$Location = 'Global'
    )

    [PSCustomObject]@{
        CheckId        = $CheckMetadata.id
        Status         = $Status
        StatusExtended = $StatusExtended
        ResourceId     = $ResourceId
        ResourceName   = $ResourceName
        Location       = $Location
        Severity       = $CheckMetadata.severity
    }
}
