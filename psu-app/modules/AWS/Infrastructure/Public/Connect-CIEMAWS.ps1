function Connect-CIEMAWS {
    <#
    .SYNOPSIS
        Internal function to establish AWS authentication.

    .DESCRIPTION
        Authenticates to AWS using one of:
        - CurrentProfile: Uses existing AWS CLI configuration (profile + region)
        - AccessKey: Uses access key credentials from PSU secrets

        Returns an auth context object with account details.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$AuthenticationProfile
    )

    $ErrorActionPreference = 'Stop'

    Write-CIEMLog -Message "Connect-CIEMAWS started" -Severity INFO -Component 'Connect-CIEMAWS'

    $awsProvider = Get-CIEMProvider -Name 'AWS'
    if (-not $awsProvider) {
        throw "AWS provider not configured. Use New-CIEMProvider -Name 'AWS' to create it."
    }

    $profile = if ($AuthenticationProfile) {
        $AuthenticationProfile
    }
    else {
        GetCIEMAssignedAuthenticationProfile -UsageType 'ProviderDiscovery' -UsageId 'AWS'
    }
    if ($profile.Provider -ne 'AWS') {
        throw "Authentication profile '$($profile.Id)' must have provider AWS."
    }

    $settings = $profile.Settings
    $secrets = $profile.Secrets
    $authMethod = $profile.Method

    Write-CIEMLog -Message "Authentication method: $authMethod" -Severity INFO -Component 'Connect-CIEMAWS'

    $authResult = switch ($authMethod) {
        'CurrentProfile' {
            Write-CIEMLog -Message "Processing CurrentProfile authentication..." -Severity INFO -Component 'Connect-CIEMAWS'

            # Build aws sts get-caller-identity command
            $awsArgs = @('sts', 'get-caller-identity', '--output', 'json')

            $awsArgs += @('--profile', $settings.Profile)
            $awsArgs += @('--region', $settings.Region)
            Write-CIEMLog -Message "Using profile: $($settings.Profile)" -Severity DEBUG -Component 'Connect-CIEMAWS'
            Write-CIEMLog -Message "Using region: $($settings.Region)" -Severity DEBUG -Component 'Connect-CIEMAWS'

            Write-CIEMLog -Message "Calling aws sts get-caller-identity..." -Severity INFO -Component 'Connect-CIEMAWS'
            $result = & aws @awsArgs 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "AWS CLI authentication failed: $result"
            }

            $identity = $result | ConvertFrom-Json
            Write-CIEMLog -Message "Authenticated as: $($identity.Arn)" -Severity INFO -Component 'Connect-CIEMAWS'

            [PSCustomObject]@{
                AccountId   = $identity.Account
                Arn         = $identity.Arn
                UserId      = $identity.UserId
                Region      = $settings.Region
                Profile     = $settings.Profile
                AccountType = if ($identity.Arn -match ':assumed-role/') { 'AssumedRole' }
                              elseif ($identity.Arn -match ':user/') { 'IAMUser' }
                              elseif ($identity.Arn -match ':root') { 'Root' }
                              else { 'Unknown' }
                ConnectedAt = Get-Date
            }
        }
        'AccessKey' {
            Write-CIEMLog -Message "Processing AccessKey authentication..." -Severity INFO -Component 'Connect-CIEMAWS'

            $accessKeyId = $secrets.AccessKeyId
            $secretAccessKey = $secrets.SecretAccessKey

            if (-not $accessKeyId -or -not $secretAccessKey) {
                throw @"
Authentication method is 'AccessKey' but credentials not found.

Credential sources:
  AccessKeyId: Profile (resolved) $(if($accessKeyId){'[FOUND]'}else{'[MISSING]'})
  SecretAccessKey: Profile (resolved) $(if($secretAccessKey){'[FOUND]'}else{'[MISSING]'})
"@
            }

            # Set environment variables for AWS CLI
            $env:AWS_ACCESS_KEY_ID = $accessKeyId
            $env:AWS_SECRET_ACCESS_KEY = $secretAccessKey

            $env:AWS_DEFAULT_REGION = $settings.Region

            Write-CIEMLog -Message "Calling aws sts get-caller-identity with access key..." -Severity INFO -Component 'Connect-CIEMAWS'
            try {
                $result = & aws sts get-caller-identity --output json 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "AWS AccessKey authentication failed: $result"
                }
            }
            finally {
                Remove-Item Env:\AWS_ACCESS_KEY_ID
                Remove-Item Env:\AWS_SECRET_ACCESS_KEY
                Remove-Item Env:\AWS_DEFAULT_REGION
            }

            $identity = $result | ConvertFrom-Json
            Write-CIEMLog -Message "Authenticated as: $($identity.Arn)" -Severity INFO -Component 'Connect-CIEMAWS'

            [PSCustomObject]@{
                AccountId   = $identity.Account
                Arn         = $identity.Arn
                UserId      = $identity.UserId
                Region      = $settings.Region
                Profile     = $null
                AccountType = if ($identity.Arn -match ':assumed-role/') { 'AssumedRole' }
                              elseif ($identity.Arn -match ':user/') { 'IAMUser' }
                              elseif ($identity.Arn -match ':root') { 'Root' }
                              else { 'Unknown' }
                ConnectedAt = Get-Date
            }
        }
        default {
            throw "Unknown AWS authentication method '$authMethod'. Valid values: CurrentProfile, AccessKey"
        }
    }

    # Store auth context in module-scoped state for Invoke-AWSAPI
    $script:AWSAuthContext = $authResult

    Write-CIEMLog -Message "Connect-CIEMAWS completed successfully" -Severity INFO -Component 'Connect-CIEMAWS'

    $authResult
}
