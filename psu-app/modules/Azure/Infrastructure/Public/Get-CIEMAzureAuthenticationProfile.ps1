function Get-CIEMAzureAuthenticationProfile {
    [CmdletBinding()]
    [OutputType('CIEMAzureAuthenticationProfile[]')]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$Name,
        [Parameter()][string]$Method,
        [Parameter()][bool]$IsActive,
        [Parameter()][switch]$ResolveSecrets
    )

    if ($null -eq (Get-Command -Name 'Get-PSUCache' -ErrorAction SilentlyContinue)) { return @() }

    $profiles = @(Get-CIEMAzureAuthProfileCache)

    # Filter in memory
    if ($PSBoundParameters.ContainsKey('Id'))         { $profiles = @($profiles | Where-Object { $_.Id -eq $Id }) }
    if ($PSBoundParameters.ContainsKey('ProviderId'))  { $profiles = @($profiles | Where-Object { $_.ProviderId -eq $ProviderId }) }
    if ($PSBoundParameters.ContainsKey('Name'))        { $profiles = @($profiles | Where-Object { $_.Name -eq $Name }) }
    if ($PSBoundParameters.ContainsKey('Method'))      { $profiles = @($profiles | Where-Object { $_.Method -eq $Method }) }
    if ($PSBoundParameters.ContainsKey('IsActive'))    { $profiles = @($profiles | Where-Object { [bool]$_.IsActive -eq $IsActive }) }

    # Convert to class instances
    $result = @(foreach ($entry in $profiles) {
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

    # Resolve secrets from PSU vault into transient properties
    if ($ResolveSecrets) {
        foreach ($obj in $result) {
            switch ($obj.Method) {
                'ServicePrincipalSecret' {
                    $sName = if ($obj.SecretName) { $obj.SecretName } else { "CIEM_Azure_$($obj.Id)_ClientSecret" }
                    $obj.ClientSecret = Get-CIEMSecret $sName
                }
                'ServicePrincipalCertificate' {
                    $pfxName = if ($obj.SecretName) { $obj.SecretName } else { "CIEM_Azure_$($obj.Id)_CertPfx" }
                    $pwdName = if ($obj.SecretName) { ($obj.SecretName -replace '_CertPfx$', '_CertPassword') } else { "CIEM_Azure_$($obj.Id)_CertPassword" }
                    $obj.CertificatePfxBase64 = Get-CIEMSecret $pfxName
                    $obj.CertificatePassword = Get-CIEMSecret $pwdName

                    if ($obj.CertificatePfxBase64) {
                        try {
                            $pfxBytes = [System.Convert]::FromBase64String($obj.CertificatePfxBase64)
                            $flags = if ($PSVersionTable.OS -match 'Windows') {
                                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
                            } else {
                                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
                            }
                            $obj.Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                                $pfxBytes,
                                $obj.CertificatePassword,
                                $flags
                            )
                        } catch {
                            Write-CIEMLog -Message "Failed to load PFX certificate for profile '$($obj.Name)': $_" -Severity ERROR -Component 'Get-CIEMAzureAuthenticationProfile'
                        }
                    }
                }
                'ManagedIdentity' {
                    # No secrets to resolve
                }
            }
        }
    }

    $result
}
