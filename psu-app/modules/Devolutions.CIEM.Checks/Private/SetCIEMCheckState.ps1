function SetCIEMCheckState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [bool]$Disabled
    )

    $ErrorActionPreference = 'Stop'

    Invoke-CIEMQuery -Query @"
INSERT INTO checks (id, disabled)
VALUES (@id, @disabled)
ON CONFLICT(id) DO UPDATE SET
    disabled = excluded.disabled
"@ -Parameters @{
        id       = $Id
        disabled = if ($Disabled) { 1 } else { 0 }
    } -AsNonQuery | Out-Null
}
