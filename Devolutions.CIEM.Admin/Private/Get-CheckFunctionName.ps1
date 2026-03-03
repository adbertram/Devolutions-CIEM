function Get-CheckFunctionName {
    <#
    .SYNOPSIS
        Converts a Prowler check ID (snake_case) to a PowerShell function name (Test-PascalCase).
    .PARAMETER CheckId
        The Prowler check ID (e.g., 'entra_security_defaults_enabled').
    .OUTPUTS
        [string] The function name (e.g., 'Test-EntraSecurityDefaultsEnabled').
    #>
    param([Parameter(Mandatory)][string]$CheckId)

    $parts = $CheckId -split '_' | ForEach-Object {
        if ($_.Length -gt 0) {
            $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()
        }
    }
    "Test-$($parts -join '')"
}
