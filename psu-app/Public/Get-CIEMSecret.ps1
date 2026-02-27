function Get-CIEMSecret {
    <#
    .SYNOPSIS
        Retrieves a secret from PSU's Secret: drive.

    .DESCRIPTION
        Safe wrapper for accessing PSU secrets. Returns $null when not running
        in PSU context or when the secret doesn't exist. Avoids parse-time errors
        from $Secret: variable syntax.

    .PARAMETER Name
        The secret name (without 'Secret:' prefix).

    .OUTPUTS
        [string] The secret value, or $null if not found/not in PSU context.

    .EXAMPLE
        $clientSecret = Get-CIEMSecret 'CIEM_Azure_ClientSecret'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
    if ($inPSUContext) {
        Get-Item "Secret:$Name" -ErrorAction SilentlyContinue
    }
}
