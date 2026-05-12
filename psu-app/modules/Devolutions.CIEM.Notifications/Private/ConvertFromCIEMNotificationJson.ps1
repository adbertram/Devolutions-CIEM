function ConvertFromCIEMNotificationJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Json
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($Json)) {
        throw 'Notification JSON content is required.'
    }

    $Json | ConvertFrom-Json -NoEnumerate
}
