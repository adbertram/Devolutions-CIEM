function Get-CIEMAzureArmResource {
    [CmdletBinding()]
    [OutputType('CIEMAzureArmResource[]')]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [string]$Type,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string]$SubscriptionId,

        [Parameter()]
        [string]$ResourceGroup
    )

    $ErrorActionPreference = 'Stop'

    GetCIEMAzureEntity -Entity 'ArmResource' -Filters $PSBoundParameters
}
