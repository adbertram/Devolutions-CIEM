function Test-IamUserConsoleAccessUnused {
    <#
    .SYNOPSIS
        IAM user console access is disabled, used within the configured inactivity period, or never used

    .DESCRIPTION
        **IAM users** with console access are evaluated by `password_last_used`. Inactivity beyond `max_console_access_days` (default `45`) marks **stale console access**.
        
        *Users without console access are excluded*.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: iam_user_console_access_unused

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_user_console_access_unused for reference.', 'N/A', 'iam Resources')
}
