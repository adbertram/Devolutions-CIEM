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
    param()

    $ErrorActionPreference = 'Stop'

    Write-CIEMLog -Message "Connect-CIEMAWS started" -Severity INFO -Component 'Connect-CIEMAWS'

    $authConfig = $script:Config.aws.authentication
    $authMethod = $authConfig.method

    Write-CIEMLog -Message "Authentication method from config: $authMethod" -Severity INFO -Component 'Connect-CIEMAWS'

    switch ($authMethod) {
        'CurrentProfile' {
            Write-CIEMLog -Message "Processing CurrentProfile authentication..." -Severity INFO -Component 'Connect-CIEMAWS'

            # Build aws sts get-caller-identity command
            $awsArgs = @('sts', 'get-caller-identity', '--output', 'json')

            if ($authConfig.profile) {
                $awsArgs += @('--profile', $authConfig.profile)
                Write-CIEMLog -Message "Using profile: $($authConfig.profile)" -Severity DEBUG -Component 'Connect-CIEMAWS'
            }
            if ($authConfig.region) {
                $awsArgs += @('--region', $authConfig.region)
                Write-CIEMLog -Message "Using region: $($authConfig.region)" -Severity DEBUG -Component 'Connect-CIEMAWS'
            }

            Write-CIEMLog -Message "Calling aws sts get-caller-identity..." -Severity INFO -Component 'Connect-CIEMAWS'
            $result = & aws @awsArgs 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "AWS CLI authentication failed: $result"
            }

            $identity = $result | ConvertFrom-Json
            Write-CIEMLog -Message "Authenticated as: $($identity.Arn)" -Severity INFO -Component 'Connect-CIEMAWS'

            $region = if ($authConfig.region) { $authConfig.region } else {
                # Try to get default region from AWS CLI
                $defaultRegion = & aws configure get region 2>$null
                if ($defaultRegion) { $defaultRegion.Trim() } else { 'us-east-1' }
            }

            [PSCustomObject]@{
                AccountId   = $identity.Account
                Arn         = $identity.Arn
                UserId      = $identity.UserId
                Region      = $region
                Profile     = $authConfig.profile
                AccountType = if ($identity.Arn -match ':assumed-role/') { 'AssumedRole' }
                              elseif ($identity.Arn -match ':user/') { 'IAMUser' }
                              elseif ($identity.Arn -match ':root') { 'Root' }
                              else { 'Unknown' }
                ConnectedAt = Get-Date
            }
        }
        'AccessKey' {
            Write-CIEMLog -Message "Processing AccessKey authentication..." -Severity INFO -Component 'Connect-CIEMAWS'

            # Read credentials from PSU secrets
            $accessKeyId = Get-CIEMSecret 'CIEM_AWS_AccessKeyId'
            $secretAccessKey = Get-CIEMSecret 'CIEM_AWS_SecretAccessKey'

            if (-not $accessKeyId -or -not $secretAccessKey) {
                throw @"
Authentication method is 'AccessKey' but credentials not found.

Credential sources:
  AccessKeyId: PSU secret -> CIEM_AWS_AccessKeyId $(if($accessKeyId){'[FOUND]'}else{'[MISSING]'})
  SecretAccessKey: PSU secret -> CIEM_AWS_SecretAccessKey $(if($secretAccessKey){'[FOUND]'}else{'[MISSING]'})
"@
            }

            # Set environment variables for AWS CLI
            $env:AWS_ACCESS_KEY_ID = $accessKeyId
            $env:AWS_SECRET_ACCESS_KEY = $secretAccessKey

            $region = if ($authConfig.region) { $authConfig.region } else { 'us-east-1' }
            $env:AWS_DEFAULT_REGION = $region

            Write-CIEMLog -Message "Calling aws sts get-caller-identity with access key..." -Severity INFO -Component 'Connect-CIEMAWS'
            $result = & aws sts get-caller-identity --output json 2>&1
            if ($LASTEXITCODE -ne 0) {
                # Clean up env vars on failure
                Remove-Item Env:\AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
                Remove-Item Env:\AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
                Remove-Item Env:\AWS_DEFAULT_REGION -ErrorAction SilentlyContinue
                throw "AWS AccessKey authentication failed: $result"
            }

            $identity = $result | ConvertFrom-Json
            Write-CIEMLog -Message "Authenticated as: $($identity.Arn)" -Severity INFO -Component 'Connect-CIEMAWS'

            [PSCustomObject]@{
                AccountId   = $identity.Account
                Arn         = $identity.Arn
                UserId      = $identity.UserId
                Region      = $region
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

    Write-CIEMLog -Message "Connect-CIEMAWS completed successfully" -Severity INFO -Component 'Connect-CIEMAWS'
}
