function GetCIEMNotificationSeverityRank {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Critical', 'High', 'Medium', 'Low', 'Info')]
        [string]$Severity
    )

    $ErrorActionPreference = 'Stop'

    switch ($Severity) {
        'Critical' { 1 }
        'High' { 2 }
        'Medium' { 3 }
        'Low' { 4 }
        'Info' { 5 }
    }
}
