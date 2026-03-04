function New-CIEMAzureAuthenticationProfile {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a configuration object')]
    [OutputType('CIEMAzureAuthenticationProfile[]')]
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
        if ($null -eq (Get-Command -Name 'Get-PSUCache' -ErrorAction SilentlyContinue)) {
            throw "Not running in PSU context. Cannot access PSU Cache."
        }

        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            $entries = $InputObject
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

            $profiles = Get-CIEMAzureAuthProfileCache

            # Check for duplicate
            $existing = $profiles | Where-Object { $_.Id -eq $cId }
            if ($existing) { throw "Azure authentication profile '$cId' already exists." }

            # Append and write back
            $profiles.Add($entry)
            Set-CIEMAzureAuthProfileCache -Profiles $profiles

            # Return created object
            Get-CIEMAzureAuthenticationProfile -Id $cId
        }
    }
}
