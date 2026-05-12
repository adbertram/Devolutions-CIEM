function ConvertFromCIEMNotificationJsonArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Json
    )

    $ErrorActionPreference = 'Stop'

    $value = ConvertFromCIEMNotificationJson -Json $Json
    if ($null -eq $value) {
        return
    }
    if ($value -isnot [array]) {
        throw 'Notification JSON content must be an array.'
    }

    foreach ($item in $value) {
        $item
    }
}
