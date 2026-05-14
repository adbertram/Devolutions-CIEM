function Test-CIEMPSGalleryPackageVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [version]$Version
    )

    $ErrorActionPreference = 'Stop'

    $safeName = $Name.Replace("'", "''")
    $safeVersion = $Version.ToString().Replace("'", "''")
    $uri = "https://www.powershellgallery.com/api/v2/Packages(Id='$safeName',Version='$safeVersion')"

    try {
        Invoke-RestMethod -Uri $uri -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        if ($statusCode -eq [System.Net.HttpStatusCode]::NotFound) {
            return $false
        }

        throw
    }
}
