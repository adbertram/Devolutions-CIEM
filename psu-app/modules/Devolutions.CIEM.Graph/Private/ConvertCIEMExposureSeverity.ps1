function ConvertCIEMExposureSeverityRank {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Severity
    )

    switch ($Severity.ToLowerInvariant()) {
        'critical' { 1 }
        'high' { 2 }
        'medium' { 3 }
        'low' { 4 }
        default { throw "Unsupported exposure severity '$Severity'." }
    }
}

function ConvertToCIEMExposureSeverityLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Severity
    )

    switch ($Severity.ToLowerInvariant()) {
        'critical' { 'Critical' }
        'high' { 'High' }
        'medium' { 'Medium' }
        'low' { 'Low' }
        default { throw "Unsupported exposure severity '$Severity'." }
    }
}

function TestCIEMExposureSeverityIsRisk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Severity
    )

    (ConvertToCIEMExposureSeverityLabel -Severity $Severity) -ne 'Low'
}
