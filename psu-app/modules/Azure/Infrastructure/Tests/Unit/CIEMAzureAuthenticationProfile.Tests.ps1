BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    $rsa = [System.Security.Cryptography.RSA]::Create(2048)
    $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=CIEM Passwordless Certificate Test',
        $rsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $certificate = $request.CreateSelfSigned(
        [DateTimeOffset]::UtcNow.AddDays(-1),
        [DateTimeOffset]::UtcNow.AddDays(1)
    )
    $script:PasswordlessPfxBase64 = [Convert]::ToBase64String(
        $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx)
    )
    $certificate.Dispose()
    $rsa.Dispose()
}

Describe 'CIEM Azure authentication profile cache operations' {

    Context 'when PSU cache is unavailable' {
        BeforeAll {
            InModuleScope Devolutions.CIEM {
                Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Get-PSUCache' }
            }
        }

        It 'throws when reading profiles' {
            InModuleScope Devolutions.CIEM {
                { Get-CIEMAzureAuthenticationProfile } | Should -Throw '*Cannot access PSU Cache*'
            }
        }

        It 'throws when saving a profile' {
            InModuleScope Devolutions.CIEM {
                {
                    Save-CIEMAzureAuthenticationProfile `
                        -Id 'profile-unavailable' `
                        -ProviderId 'Azure' `
                        -Name 'Unavailable Cache' `
                        -Method 'ManagedIdentity' `
                        -TenantId 'tenant-unavailable'
                } | Should -Throw '*Cannot access PSU Cache*'
            }
        }

        It 'throws when removing a profile' {
            InModuleScope Devolutions.CIEM {
                { Remove-CIEMAzureAuthenticationProfile -Id 'profile-unavailable' -Confirm:$false } |
                    Should -Throw '*Cannot access PSU Cache*'
            }
        }
    }

    Context 'when PSU cache read fails' {
        BeforeAll {
            InModuleScope Devolutions.CIEM {
                Mock Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' }
                Mock Get-PSUCache { throw 'PSU cache read failed' }
            }
        }

        It 'throws the cache read error while reading profiles' {
            InModuleScope Devolutions.CIEM {
                { Get-CIEMAzureAuthenticationProfile } | Should -Throw '*PSU cache read failed*'
            }
        }

        It 'throws the cache read error while saving a profile' {
            InModuleScope Devolutions.CIEM {
                {
                    Save-CIEMAzureAuthenticationProfile `
                        -Id 'profile-read-fails' `
                        -ProviderId 'Azure' `
                        -Name 'Read Fails' `
                        -Method 'ManagedIdentity' `
                        -TenantId 'tenant-read-fails'
                } | Should -Throw '*PSU cache read failed*'
            }
        }
    }

    Context 'when resolving a certificate profile without a password secret' {
        BeforeAll {
            InModuleScope Devolutions.CIEM -Parameters @{ PasswordlessPfxBase64 = $script:PasswordlessPfxBase64 } {
                $script:TestPasswordlessPfxBase64 = $PasswordlessPfxBase64

                Mock GetCIEMAzureAuthProfileCache {
                    $profiles = [System.Collections.Generic.List[object]]::new()
                    $profiles.Add([PSCustomObject]@{
                        Id         = 'cert-passwordless'
                        ProviderId = 'Azure'
                        Name       = 'Passwordless Certificate'
                        Method     = 'ServicePrincipalCertificate'
                        IsActive   = $true
                        TenantId   = 'tenant-passwordless'
                        ClientId   = 'client-passwordless'
                        SecretName = 'cert-passwordless_CertPfx'
                        SecretType = 'Certificate'
                        CreatedAt  = (Get-Date).ToString('o')
                        UpdatedAt  = (Get-Date).ToString('o')
                    })
                    , $profiles
                }
                Mock Get-CIEMSecret { $script:TestPasswordlessPfxBase64 } -ParameterFilter {
                    $Name -eq 'cert-passwordless_CertPfx'
                }
                Mock Get-CIEMSecret { throw 'Password secret should not be requested' } -ParameterFilter {
                    $Name -eq 'cert-passwordless_CertPassword'
                }
                Mock Test-Path { $false } -ParameterFilter {
                    $Path -eq 'Secret:cert-passwordless_CertPassword'
                }
            }
        }

        It 'loads the PFX without requiring a certificate password secret' {
            InModuleScope Devolutions.CIEM {
                $profile = Get-CIEMAzureAuthenticationProfile -Id 'cert-passwordless' -ResolveSecrets

                $profile.CertificatePfxBase64 | Should -Not -BeNullOrEmpty
                $profile.CertificatePassword | Should -BeNullOrEmpty
                $profile.Certificate | Should -Not -BeNullOrEmpty
                $profile.Certificate.Subject | Should -Be 'CN=CIEM Passwordless Certificate Test'

                Should -Invoke -CommandName Get-CIEMSecret -ModuleName Devolutions.CIEM -ParameterFilter {
                    $Name -eq 'cert-passwordless_CertPassword'
                } -Times 0 -Exactly
            }
        }
    }
}
