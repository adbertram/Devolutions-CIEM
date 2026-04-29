function Get-CIEMAzureEntraResource {
    [CmdletBinding()]
    [OutputType('CIEMAzureEntraResource[]')]
    param(
        [Parameter()]
        [string]$Id,
        [Parameter()]
        [string]$Type,
        [Parameter()]
        [string]$DisplayName,
        [Parameter()]
        [string]$ParentId
    )

    $ErrorActionPreference = 'Stop'

    GetCIEMAzureEntity -Entity 'EntraResource' -Filters $PSBoundParameters
}
