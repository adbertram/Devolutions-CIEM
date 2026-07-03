function GetCIEMSHA256Hash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputText
    )

    $ErrorActionPreference = 'Stop'

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}
