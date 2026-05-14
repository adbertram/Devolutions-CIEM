function Save-CIEMAuthenticationProfile {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [hashtable]$Settings,

        [Parameter()]
        [hashtable]$SecretRefs = @{}
    )

    $ErrorActionPreference = 'Stop'

    TestCIEMAuthenticationProfileInput -Provider $Provider -Method $Method -Settings $Settings -SecretRefs $SecretRefs

    $profileId = if ([string]::IsNullOrWhiteSpace($Id)) { [guid]::NewGuid().ToString() } else { $Id }
    $now = (Get-Date).ToString('o')
    $settingsJson = ConvertToCIEMAuthenticationProfileJson -InputObject $Settings
    $secretRefsJson = ConvertToCIEMAuthenticationProfileJson -InputObject $SecretRefs
    $newSecretRefs = ConvertFromCIEMAuthenticationProfileJson -Json $secretRefsJson
    $existing = @(Invoke-CIEMQuery -Query 'SELECT provider, method, secret_refs_json, created_at FROM authentication_profiles WHERE id = @id' -Parameters @{ id = $profileId })
    $createdAt = if ($existing.Count -eq 1) { [string]$existing[0].created_at } else { $now }
    $staleSecretNames = @()

    if ($existing.Count -eq 1) {
        $providerChanged = [string]$existing[0].provider -ne $Provider
        $methodChanged = [string]$existing[0].method -ne $Method
        if ($providerChanged -or $methodChanged) {
            $assignments = @(Get-CIEMAuthenticationProfileAssignment -AuthenticationProfileId $profileId)
            if ($assignments.Count -gt 0) {
                $assignment = $assignments[0]
                throw "Authentication profile '$profileId' is assigned to $($assignment.UsageType) '$($assignment.UsageId)' and cannot change provider or method."
            }
        }

        $existingSecretRefs = ConvertFromCIEMAuthenticationProfileJson -Json ([string]$existing[0].secret_refs_json)
        $newOwnedSecretNames = @(GetCIEMAuthenticationProfileOwnedSecretName -ProfileId $profileId -SecretRefs $newSecretRefs)
        $staleSecretNames = @(GetCIEMAuthenticationProfileOwnedSecretName -ProfileId $profileId -SecretRefs $existingSecretRefs | Where-Object {
                $newOwnedSecretNames -notcontains [string]$_
            })
    }

    Invoke-CIEMQuery -Query @"
INSERT INTO authentication_profiles (
    id, name, provider, method, settings_json, secret_refs_json, created_at, updated_at
)
VALUES (
    @id, @name, @provider, @method, @settings_json, @secret_refs_json, @created_at, @updated_at
)
ON CONFLICT(id) DO UPDATE SET
    name = excluded.name,
    provider = excluded.provider,
    method = excluded.method,
    settings_json = excluded.settings_json,
    secret_refs_json = excluded.secret_refs_json,
    updated_at = excluded.updated_at
"@ -Parameters @{
        id               = $profileId
        name             = $Name
        provider         = $Provider
        method           = $Method
        settings_json    = $settingsJson
        secret_refs_json = $secretRefsJson
        created_at       = $createdAt
        updated_at       = $now
    } -AsNonQuery | Out-Null

    foreach ($secretName in $staleSecretNames) {
        Remove-CIEMSecret -Name $secretName
    }

    Get-CIEMAuthenticationProfile -Id $profileId
}
