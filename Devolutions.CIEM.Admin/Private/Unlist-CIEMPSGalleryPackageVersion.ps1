function Unlist-CIEMPSGalleryPackageVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [version]$Version,

        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    $ErrorActionPreference = 'Stop'

    $uri = "https://www.powershellgallery.com/api/v2/package/$Name/$Version"
    Invoke-WebRequest `
        -Uri $uri `
        -Method Delete `
        -Headers @{ 'X-NuGet-ApiKey' = $ApiKey } `
        -UseBasicParsing `
        -ErrorAction Stop | Out-Null
}
