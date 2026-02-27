function Set-CIEMSecret {
    <#
    .SYNOPSIS
        Stores a secret in PSU's Secret: drive.

    .DESCRIPTION
        Safe wrapper for setting PSU secrets. Does nothing when not running
        in PSU context. Avoids parse-time errors from $Secret: variable syntax.

    .PARAMETER Name
        The secret name (without 'Secret:' prefix).

    .PARAMETER Value
        The secret value to store.

    .EXAMPLE
        Set-CIEMSecret 'CIEM_Azure_ClientSecret' $clientSecret
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Value
    )

    $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
    if ($inPSUContext) {
        # PSU Secret: drive doesn't support Set-Item - use PSU cmdlets instead
        $existingVar = Get-PSUVariable -Name $Name -ErrorAction SilentlyContinue
        if ($existingVar) {
            Set-PSUVariable -Variable $existingVar -Value $Value -ErrorAction SilentlyContinue | Out-Null
        } else {
            New-PSUVariable -Name $Name -Value $Value -Vault 'Database' -ErrorAction SilentlyContinue | Out-Null
        }
    }
}
