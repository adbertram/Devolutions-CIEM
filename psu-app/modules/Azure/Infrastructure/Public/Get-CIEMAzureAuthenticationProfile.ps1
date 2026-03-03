function Get-CIEMAzureAuthenticationProfile {
    [CmdletBinding()]
    [OutputType('CIEMAzureAuthenticationProfile[]')]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$Name,
        [Parameter()][string]$Method,
        [Parameter()][bool]$IsActive
    )

    $ErrorActionPreference = 'Stop'

    # Read profiles from PSU Variable (returns empty if not in PSU context)
    $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
    if (-not $inPSUContext) { return @() }

    $raw = (Get-PSUVariable -Name 'CIEM_AuthProfiles_Azure' -ErrorAction SilentlyContinue).Value
    $profiles = @()
    if ($raw) { $profiles = @($raw | ConvertFrom-Json) }

    # Filter in memory
    if ($PSBoundParameters.ContainsKey('Id'))         { $profiles = @($profiles | Where-Object { $_.Id -eq $Id }) }
    if ($PSBoundParameters.ContainsKey('ProviderId'))  { $profiles = @($profiles | Where-Object { $_.ProviderId -eq $ProviderId }) }
    if ($PSBoundParameters.ContainsKey('Name'))        { $profiles = @($profiles | Where-Object { $_.Name -eq $Name }) }
    if ($PSBoundParameters.ContainsKey('Method'))      { $profiles = @($profiles | Where-Object { $_.Method -eq $Method }) }
    if ($PSBoundParameters.ContainsKey('IsActive'))    { $profiles = @($profiles | Where-Object { [bool]$_.IsActive -eq $IsActive }) }

    # Convert to class instances
    @(foreach ($entry in $profiles) {
        $obj = [CIEMAzureAuthenticationProfile]::new()
        $obj.Id = $entry.Id
        $obj.ProviderId = $entry.ProviderId
        $obj.Name = $entry.Name
        $obj.Method = $entry.Method
        $obj.IsActive = [bool]$entry.IsActive
        $obj.TenantId = $entry.TenantId
        $obj.ClientId = $entry.ClientId
        $obj.ManagedIdentityClientId = $entry.ManagedIdentityClientId
        $obj.SecretName = $entry.SecretName
        $obj.SecretType = $entry.SecretType
        $obj.CreatedAt = if ($entry.CreatedAt) { [datetime]$entry.CreatedAt } else { [datetime]::MinValue }
        $obj.UpdatedAt = if ($entry.UpdatedAt) { [datetime]$entry.UpdatedAt } else { [datetime]::MinValue }
        $obj
    })
}
