function Get-CIEMSeverityRank {
    <#
    .SYNOPSIS
        Returns the numeric sort rank for a severity level.
    .DESCRIPTION
        Looks up the severity in the module-scope severity catalog and returns
        its rank (1 = most severe). Unknown severities return 999 so they sort
        after all known entries.
    .EXAMPLE
        Get-CIEMSeverityRank -Severity 'critical'   # 1
        Get-CIEMSeverityRank -Severity 'high'       # 2
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Severity
    )

    $ErrorActionPreference = 'Stop'

    $entry = $script:SeverityByName[$Severity.ToLower()]
    if ($entry) { [int]$entry.rank } else { 999 }
}
