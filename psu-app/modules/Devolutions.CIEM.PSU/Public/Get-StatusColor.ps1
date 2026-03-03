function Get-StatusColor {
    param([string]$Status)
    if ($Status -eq 'FAIL') { '#f44336' } else { '#4caf50' }
}
