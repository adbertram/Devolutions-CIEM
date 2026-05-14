function ConvertFromCIEMAuthenticationProfileJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Json
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($Json)) {
        throw 'Authentication profile JSON content is required.'
    }

    $Json | ConvertFrom-Json -NoEnumerate
}
