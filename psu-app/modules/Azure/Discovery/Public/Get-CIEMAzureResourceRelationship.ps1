function Get-CIEMAzureResourceRelationship {
    [CmdletBinding()]
    [OutputType('CIEMAzureResourceRelationship[]')]
    param(
        [Parameter()]
        [int]$Id,

        [Parameter()]
        [string]$SourceId,

        [Parameter()]
        [string]$SourceType,

        [Parameter()]
        [string]$TargetId,

        [Parameter()]
        [string]$TargetType,

        [Parameter()]
        [string]$Relationship
    )

    $ErrorActionPreference = 'Stop'

    GetCIEMAzureEntity -Entity 'ResourceRelationship' -Filters $PSBoundParameters
}
