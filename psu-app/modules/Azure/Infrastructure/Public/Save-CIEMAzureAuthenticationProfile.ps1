function Save-CIEMAzureAuthenticationProfile {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Name,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Method,
        [Parameter(ParameterSetName = 'ByProperties')][bool]$IsActive = $true,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$TenantId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ClientId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ManagedIdentityClientId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$SecretName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$SecretType,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [object[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'

        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            # Strip transient properties (resolved secrets) to prevent leaking into PSU Cache
            $entries = @(foreach ($io in $InputObject) {
                [PSCustomObject]@{
                    Id                     = $io.Id
                    ProviderId             = $io.ProviderId
                    Name                   = $io.Name
                    Method                 = $io.Method
                    IsActive               = $io.IsActive
                    TenantId               = $io.TenantId
                    ClientId               = $io.ClientId
                    ManagedIdentityClientId = $io.ManagedIdentityClientId
                    SecretName             = $io.SecretName
                    SecretType             = $io.SecretType
                    CreatedAt              = $io.CreatedAt
                    UpdatedAt              = $io.UpdatedAt
                }
            })
        } else {
            $now = (Get-Date).ToString('o')
            $entries = @([PSCustomObject]@{
                Id = $Id; ProviderId = $ProviderId; Name = $Name; Method = $Method
                IsActive = $IsActive; TenantId = $TenantId; ClientId = $ClientId
                ManagedIdentityClientId = $ManagedIdentityClientId; SecretName = $SecretName
                SecretType = $SecretType; CreatedAt = $now; UpdatedAt = $now
            })
        }

        foreach ($entry in $entries) {
            $cId = $entry.Id

            $profiles = GetCIEMAzureAuthProfileCache

            # Upsert: replace existing or append
            $existingIdx = -1
            for ($i = 0; $i -lt $profiles.Count; $i++) {
                if ($profiles[$i].Id -eq $cId) { $existingIdx = $i; break }
            }
            if ($existingIdx -ge 0) {
                $entry.CreatedAt = $profiles[$existingIdx].CreatedAt
                $profiles[$existingIdx] = $entry
            } else {
                $profiles.Add($entry)
            }

            SetCIEMAzureAuthProfileCache -Profiles $profiles
        }
    }
}
