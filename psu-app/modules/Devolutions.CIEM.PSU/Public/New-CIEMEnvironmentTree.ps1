function New-CIEMEnvironmentTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter()]
        [ValidateSet('LR', 'TB')]
        [string]$Orientation = 'LR',

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$Height = 700
    )

    $ErrorActionPreference = 'Stop'

    if (-not $script:CIEMEnvironmentTreeAssetId) {
        RegisterCIEMEnvironmentTreeAsset | Out-Null
    }

    @{
        assetId = $script:CIEMEnvironmentTreeAssetId
        isPlugin = $true
        type = 'ciem-environment-tree'
        id = $Id
        data = $Data
        orientation = $Orientation
        height = $Height
    }
}
