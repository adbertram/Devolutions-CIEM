function ConvertToCIEMNotificationJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $ErrorActionPreference = 'Stop'

    ConvertTo-Json -InputObject $InputObject -Depth 12 -Compress
}
