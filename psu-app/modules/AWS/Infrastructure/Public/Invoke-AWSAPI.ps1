function Invoke-AWSAPI {
    <#
    .SYNOPSIS
        Invokes AWS CLI commands with standardized error handling.

    .DESCRIPTION
        Single point of entry for all AWS CLI calls. Reads auth context
        (profile/region) from $script:AWSAuthContext set by Connect-CIEMAWS.

        Throws on any AWS CLI failure.

    .PARAMETER Service
        The AWS service name (e.g., 'iam', 's3', 'sts').

    .PARAMETER Command
        The AWS CLI command (e.g., 'list-users', 'get-account-password-policy').

    .PARAMETER Arguments
        Additional CLI arguments as an array.

    .PARAMETER ResourceName
        A friendly name for the resource being loaded, used in verbose/warning messages.

    .PARAMETER RawOutput
        Return the raw string output instead of parsing JSON.

    .OUTPUTS
        [PSObject] The parsed JSON response. Throws on failure.

    .EXAMPLE
        Invoke-AWSAPI -Service iam -Command list-users -ResourceName 'IAM Users'

    .EXAMPLE
        Invoke-AWSAPI -Service iam -Command get-credential-report -ResourceName 'Credential Report' -ErrorAction Stop
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Service,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,

        [Parameter()]
        [string[]]$Arguments = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceName,

        [Parameter()]
        [switch]$RawOutput
    )

    $ErrorActionPreference = 'Stop'

    Write-Verbose "Loading $ResourceName..."

    # Build AWS CLI arguments
    $awsArgs = @($Service, $Command) + $Arguments + @('--output', 'json')

    # Add profile/region from auth context if available
    $awsContext = $script:AWSAuthContext
    if ($awsContext) {
        if ($awsContext.Profile) {
            $awsArgs += @('--profile', $awsContext.Profile)
        }
        if ($awsContext.Region) {
            $awsArgs += @('--region', $awsContext.Region)
        }
    }

    Write-CIEMLog -Message "AWS CLI: aws $Service $Command $($Arguments -join ' ')" -Severity DEBUG -Component 'Invoke-AWSAPI'

    # Execute AWS CLI (outside try/catch so exit-code handling is clean)
    $result = & aws @awsArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $errorText = ($result | Out-String).Trim()

        # Classify common AWS errors
        $msg = if ($errorText -match 'AccessDenied|not authorized') {
            "Access denied loading $ResourceName - missing permissions: $errorText"
        } elseif ($errorText -match 'ExpiredToken|SecurityTokenExpired') {
            "Token expired loading $ResourceName - re-authenticate: $errorText"
        } elseif ($errorText -match 'NoSuchEntity') {
            "Resource not found: $ResourceName"
        } elseif ($errorText -match 'could not be found|does not exist') {
            "Resource not found: $ResourceName"
        } else {
            "Failed to load $ResourceName (exit code $exitCode): $errorText"
        }

        Write-CIEMLog -Message $msg -Severity WARNING -Component 'Invoke-AWSAPI'
        throw $msg
    }

    # Parse the successful response (try/catch only around JSON parsing)
    $rawString = ($result | Out-String).Trim()

    if ($RawOutput) {
        return $rawString
    }

    if (-not $rawString) {
        Write-Verbose "Empty response for $ResourceName"
        return $null
    }

    try {
        $parsed = $rawString | ConvertFrom-Json
        Write-CIEMLog -Message "Loaded $ResourceName successfully" -Severity DEBUG -Component 'Invoke-AWSAPI'
        $parsed
    }
    catch {
        $msg = "Failed to parse $ResourceName response: $($_.Exception.Message)"
        Write-CIEMLog -Message $msg -Severity ERROR -Component 'Invoke-AWSAPI'
        throw $msg
    }
}
