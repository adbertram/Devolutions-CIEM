function Update-CIEMAzureAuthenticationProfile {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureAuthenticationProfile')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Name,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Method,
        [Parameter(ParameterSetName = 'ByProperties')][bool]$IsActive,
        [Parameter(ParameterSetName = 'ByProperties')][string]$TenantId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ClientId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ManagedIdentityClientId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$SecretName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$SecretType,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureAuthenticationProfile[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
        if (-not $inPSUContext) { throw "Not running in PSU context. Cannot access PSU Variables." }

        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')

            # Read current array from PSU Variable
            $raw = (Get-PSUVariable -Name 'CIEM_AuthProfiles_Azure' -ErrorAction SilentlyContinue).Value
            $profiles = [System.Collections.Generic.List[object]]::new()
            if ($raw) { @($raw | ConvertFrom-Json) | ForEach-Object { $profiles.Add($_) } }

            if ($item) {
                # InputObject: replace entire profile with object values
                $cId = $item.Id
                $found = $false
                for ($i = 0; $i -lt $profiles.Count; $i++) {
                    if ($profiles[$i].Id -eq $cId) {
                        $profiles[$i] = [PSCustomObject]@{
                            Id = $item.Id; ProviderId = $item.ProviderId; Name = $item.Name; Method = $item.Method
                            IsActive = $item.IsActive; TenantId = $item.TenantId; ClientId = $item.ClientId
                            ManagedIdentityClientId = $item.ManagedIdentityClientId; SecretName = $item.SecretName
                            SecretType = $item.SecretType; CreatedAt = $profiles[$i].CreatedAt; UpdatedAt = $now
                        }
                        $found = $true; break
                    }
                }
                if (-not $found) { throw "Azure authentication profile '$cId' not found." }
            } else {
                # ByProperties: partial update via PSBoundParameters
                $cId = $Id
                $found = $false
                for ($i = 0; $i -lt $profiles.Count; $i++) {
                    if ($profiles[$i].Id -eq $cId) {
                        $p = $profiles[$i]
                        foreach ($paramName in @('Name', 'Method', 'IsActive', 'TenantId', 'ClientId', 'ManagedIdentityClientId', 'SecretName', 'SecretType')) {
                            if ($PSBoundParameters.ContainsKey($paramName)) {
                                $p.$paramName = $PSBoundParameters[$paramName]
                            }
                        }
                        $p.UpdatedAt = $now
                        $found = $true; break
                    }
                }
                if (-not $found) { throw "Azure authentication profile '$cId' not found." }
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

            if ($PassThru) { Get-CIEMAzureAuthenticationProfile -Id $cId }
        }
    }
}
