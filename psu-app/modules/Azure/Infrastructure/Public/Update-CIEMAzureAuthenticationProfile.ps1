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
        [object[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        if ($null -eq (Get-Command -Name 'Get-PSUCache' -ErrorAction SilentlyContinue)) {
            throw "Not running in PSU context. Cannot access PSU Cache."
        }

        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $now = (Get-Date).ToString('o')
                $cId = $item.Id

                $profiles = GetCIEMAzureAuthProfileCache

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

                SetCIEMAzureAuthProfileCache -Profiles $profiles

                if ($PassThru) { Get-CIEMAzureAuthenticationProfile -Id $cId }
            }
        } else {
            $now = (Get-Date).ToString('o')
            $cId = $Id

            $profiles = GetCIEMAzureAuthProfileCache

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

            SetCIEMAzureAuthProfileCache -Profiles $profiles

            if ($PassThru) { Get-CIEMAzureAuthenticationProfile -Id $cId }
        }
    }
}