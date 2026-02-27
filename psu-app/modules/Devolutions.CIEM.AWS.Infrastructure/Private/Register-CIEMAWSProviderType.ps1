function Register-CIEMAWSProviderType {
    <#
    .SYNOPSIS
        Registers the AWS provider type with CIEM Base.
    .DESCRIPTION
        Called during AWS module import. Registers callbacks that Base uses
        for provider CRUD, auth testing, and auth building.
    #>
    [CmdletBinding()]
    param()

    Register-CIEMProviderType -Name 'AWS' -Callbacks @{
        DefaultEndpoints = [PSCustomObject]@{}

        QueryAuth = {
            # AWS has no auth profile table — return empty fragments
            @{ Columns = ''; JoinClause = '' }
        }

        ReadAuth = {
            param($Row, [bool]$IncludeSecrets)
            $auth = [PSCustomObject]@{
                Provider = 'AWS'
                Enabled  = if ($null -ne $Row.Enabled) { [bool]$Row.Enabled } elseif ($null -ne $Row.enabled) { [bool]$Row.enabled } else { $false }
                Method   = if ($Row.PSObject.Properties['Method']) { $Row.Method } else { 'CurrentProfile' }
                Profile  = if ($Row.PSObject.Properties['Profile']) { $Row.Profile } else { $null }
                Region   = if ($Row.PSObject.Properties['Region']) { $Row.Region } else { $null }
            }
            if ($IncludeSecrets) {
                $auth | Add-Member -NotePropertyName 'HasAccessKeyId' -NotePropertyValue ([bool](Get-CIEMSecret 'CIEM_AWS_AccessKeyId'))
                $auth | Add-Member -NotePropertyName 'HasSecretAccessKey' -NotePropertyValue ([bool](Get-CIEMSecret 'CIEM_AWS_SecretAccessKey'))
            }
            $auth
        }

        WriteAuth = {
            param($Connection, [string]$ProviderId, $Auth, [string]$Timestamp)
            # AWS has no auth profile table — no-op
            # Auth config (profile, region) is stored on the provider object via Update-CIEMProvider
        }

        TestAuth = {
            param($Provider)
            $result = [PSCustomObject]@{
                Authenticated = $false
                Account       = $null
                TenantId      = $null
            }
            try {
                $awsContext = $script:AWSAuthContext
                if ($awsContext -and $awsContext.AccountId) {
                    $result.Authenticated = $true
                    $result.Account = $awsContext.Arn
                }
            }
            catch {
                Write-Verbose "AWS auth check failed: $($_.Exception.Message)"
            }
            $result
        }

        BuildAuth = {
            param([hashtable]$Params)
            $newAuth = [PSCustomObject]@{
                Provider = 'AWS'
                Enabled  = $true
                Method   = $Params.Method
                Profile  = $null
                Region   = $Params.Region
            }
            switch ($Params.Method) {
                'CurrentProfile' {
                    $newAuth.Profile = $Params.Profile
                }
                'AccessKey' {
                    if ($Params.AccessKeyId) {
                        Set-CIEMSecret 'CIEM_AWS_AccessKeyId' $Params.AccessKeyId
                        Write-CIEMLog -Message "Saved CIEM_AWS_AccessKeyId to PSU secrets" -Severity DEBUG -Component 'AWS-BuildAuth'
                    }
                    if ($Params.SecretAccessKey) {
                        Set-CIEMSecret 'CIEM_AWS_SecretAccessKey' $Params.SecretAccessKey
                        Write-CIEMLog -Message "Saved CIEM_AWS_SecretAccessKey to PSU secrets" -Severity DEBUG -Component 'AWS-BuildAuth'
                    }
                }
            }
            $newAuth
        }

        SeedDefaults = {
            param($Connection, [string]$Timestamp)
            Invoke-PSUSQLiteQuery -Connection $Connection -Query "INSERT OR IGNORE INTO providers (id, name, type, enabled, is_default, created_at, updated_at) VALUES (@id, @name, @type, @enabled, @is_default, @now, @now)" -Parameters @{
                id = 'aws'; name = 'AWS'; type = 'AWS'; enabled = 0; is_default = 0; now = $Timestamp
            } -AsNonQuery | Out-Null
        }
    }
}
