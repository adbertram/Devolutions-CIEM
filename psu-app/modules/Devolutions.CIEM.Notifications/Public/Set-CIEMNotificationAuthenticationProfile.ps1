function Set-CIEMNotificationAuthenticationProfile {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('SmtpAnonymous', 'SmtpBasic')]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Host,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory)]
        [ValidateSet('None', 'StartTls', 'Ssl')]
        [string]$TlsMode,

        [Parameter()]
        [string]$Username,

        [Parameter()]
        [string]$PasswordSecretName
    )

    $ErrorActionPreference = 'Stop'

    if ($Method -eq 'SmtpBasic') {
        if ([string]::IsNullOrWhiteSpace($Username)) {
            throw 'Username is required when Method is SmtpBasic.'
        }
        if ([string]::IsNullOrWhiteSpace($PasswordSecretName)) {
            throw 'PasswordSecretName is required when Method is SmtpBasic.'
        }
    }

    $id = 'email-smtp'
    $now = (Get-Date).ToString('o')
    $existing = @(Invoke-CIEMQuery -Query 'SELECT created_at FROM notification_authentication_profiles WHERE id = @id' -Parameters @{ id = $id })
    $createdAt = if ($existing.Count -eq 1) { [string]$existing[0].created_at } else { $now }

    $settings = [ordered]@{
        Host    = $Host
        Port    = $Port
        TlsMode = $TlsMode
    }
    $secretRefs = [ordered]@{}

    if ($Method -eq 'SmtpBasic') {
        $settings.Username = $Username
        $secretRefs.Password = $PasswordSecretName
    }

    Invoke-CIEMQuery -Query @"
INSERT INTO notification_authentication_profiles (
    id, name, type, method, settings_json, secret_refs_json, created_at, updated_at
)
VALUES (
    @id, @name, 'Email', @method, @settings_json, @secret_refs_json, @created_at, @updated_at
)
ON CONFLICT(id) DO UPDATE SET
    name = excluded.name,
    type = excluded.type,
    method = excluded.method,
    settings_json = excluded.settings_json,
    secret_refs_json = excluded.secret_refs_json,
    updated_at = excluded.updated_at
"@ -Parameters @{
        id               = $id
        name             = $Name
        method           = $Method
        settings_json    = ConvertToCIEMNotificationJson -InputObject $settings
        secret_refs_json = ConvertToCIEMNotificationJson -InputObject $secretRefs
        created_at       = $createdAt
        updated_at       = $now
    } -AsNonQuery | Out-Null

    Get-CIEMNotificationAuthenticationProfile -Id $id
}
