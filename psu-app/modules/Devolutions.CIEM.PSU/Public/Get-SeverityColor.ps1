function Get-SeverityColor {
    param([string]$Severity)
    switch ($Severity) {
        'CRITICAL' { '#9c27b0' }
        'HIGH' { '#f44336' }
        'MEDIUM' { '#ff9800' }
        'LOW' { '#2196f3' }
        'INFO' { '#4caf50' }
        default { '#666' }
    }
}
