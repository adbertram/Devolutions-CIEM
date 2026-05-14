function Set-CIEMAuthenticationProfileAssignment {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ProviderDiscovery', 'NotificationChannel')]
        [string]$UsageType,

        [Parameter(Mandatory)]
        [string]$UsageId,

        [Parameter(Mandatory)]
        [string]$AuthenticationProfileId
    )

    $ErrorActionPreference = 'Stop'

    $profiles = @(Get-CIEMAuthenticationProfile -Id $AuthenticationProfileId)
    if ($profiles.Count -ne 1) {
        throw "Authentication profile '$AuthenticationProfileId' was not found."
    }
    $profile = $profiles[0]

    if ($UsageType -eq 'ProviderDiscovery' -and $profile.Provider -ne $UsageId) {
        throw "Authentication profile provider '$($profile.Provider)' cannot be assigned to provider discovery target '$UsageId'."
    }
    if ($UsageType -eq 'NotificationChannel') {
        if ($UsageId -ne 'email-default') {
            throw "Unsupported notification channel assignment target '$UsageId'."
        }
        if ($profile.Provider -ne 'Email') {
            throw "Authentication profile provider '$($profile.Provider)' cannot be assigned to notification channel '$UsageId'."
        }
    }

    $now = (Get-Date).ToString('o')
    $existing = @(Get-CIEMAuthenticationProfileAssignment -UsageType $UsageType -UsageId $UsageId)
    $createdAt = if ($existing.Count -eq 1) { $existing[0].CreatedAt } else { $now }

    Invoke-CIEMQuery -Query @"
INSERT INTO authentication_profile_assignments (
    usage_type, usage_id, authentication_profile_id, created_at, updated_at
)
VALUES (
    @usage_type, @usage_id, @authentication_profile_id, @created_at, @updated_at
)
ON CONFLICT(usage_type, usage_id) DO UPDATE SET
    authentication_profile_id = excluded.authentication_profile_id,
    updated_at = excluded.updated_at
"@ -Parameters @{
        usage_type                = $UsageType
        usage_id                  = $UsageId
        authentication_profile_id = $AuthenticationProfileId
        created_at                = $createdAt
        updated_at                = $now
    } -AsNonQuery | Out-Null

    Get-CIEMAuthenticationProfileAssignment -UsageType $UsageType -UsageId $UsageId
}
