function FormatCIEMNotificationTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Template,

        [Parameter(Mandatory)]
        [hashtable]$Values
    )

    $ErrorActionPreference = 'Stop'

    $rendered = $Template
    foreach ($key in $Values.Keys) {
        $token = '{{' + $key + '}}'
        $rendered = $rendered.Replace($token, [string]$Values[$key])
    }

    $rendered
}
