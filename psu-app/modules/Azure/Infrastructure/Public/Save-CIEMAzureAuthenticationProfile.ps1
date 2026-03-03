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
        [CIEMAzureAuthenticationProfile[]]$InputObject
    )
    process {
        $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
        if (-not $inPSUContext) { return }

        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')

            if ($item) {
                $entry = [PSCustomObject]@{
                    Id = $item.Id; ProviderId = $item.ProviderId; Name = $item.Name; Method = $item.Method
                    IsActive = $item.IsActive; TenantId = $item.TenantId; ClientId = $item.ClientId
                    ManagedIdentityClientId = $item.ManagedIdentityClientId; SecretName = $item.SecretName
                    SecretType = $item.SecretType; CreatedAt = $now; UpdatedAt = $now
                }
                $cId = $item.Id
            } else {
                $entry = [PSCustomObject]@{
                    Id = $Id; ProviderId = $ProviderId; Name = $Name; Method = $Method
                    IsActive = $IsActive; TenantId = $TenantId; ClientId = $ClientId
                    ManagedIdentityClientId = $ManagedIdentityClientId; SecretName = $SecretName
                    SecretType = $SecretType; CreatedAt = $now; UpdatedAt = $now
                }
                $cId = $Id
            }

            # Read current array from PSU Variable
            $raw = (Get-PSUVariable -Name 'CIEM_AuthProfiles_Azure' -ErrorAction SilentlyContinue).Value
            $profiles = [System.Collections.Generic.List[object]]::new()
            if ($raw) { @($raw | ConvertFrom-Json) | ForEach-Object { $profiles.Add($_) } }

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

            # Write back
            $array = @($profiles.ToArray())
            $json = if ($array.Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject $array -Depth 10 -Compress }
            $existingVar = Get-PSUVariable -Name 'CIEM_AuthProfiles_Azure' -ErrorAction SilentlyContinue
            if ($existingVar) {
                Set-PSUVariable -Variable $existingVar -Value $json | Out-Null
            } else {
                New-PSUVariable -Name 'CIEM_AuthProfiles_Azure' -Value $json | Out-Null
            }
        }
    }
}
