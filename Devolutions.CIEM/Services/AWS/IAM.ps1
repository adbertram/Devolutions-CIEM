[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$SubscriptionIds = @()
)

$ErrorActionPreference = 'Stop'

# AWS IAM service initialization - loads data upfront for all IAM checks.
# Unlike Azure, AWS IAM is account-scoped (not subscription-scoped),
# so we load data once at the top level.

$data = @{
    CredentialReport  = $null
    Users             = $null
    PasswordPolicy    = $null
    AccountSummary    = $null
    VirtualMFADevices = $null
}

# 1. Credential Report (generate-then-poll pattern)
Write-CIEMLog -Severity DEBUG -Message 'Generating IAM credential report...' -Component 'AWS-IAM'

try {
    # Trigger credential report generation
    $generateResult = Invoke-AWSAPI -Service iam -Command generate-credential-report -ResourceName 'Credential Report Generation' -ErrorAction Stop

    # Poll until report is ready (typically completes in 1-4 seconds)
    $maxWaitSeconds = 30
    $waited = 0
    $reportReady = $false

    if ($generateResult.State -eq 'COMPLETE') {
        $reportReady = $true
    }

    while (-not $reportReady -and $waited -lt $maxWaitSeconds) {
        Start-Sleep -Seconds 2
        $waited += 2
        $generateResult = Invoke-AWSAPI -Service iam -Command generate-credential-report -ResourceName 'Credential Report Generation' -ErrorAction Stop
        if ($generateResult.State -eq 'COMPLETE') {
            $reportReady = $true
        }
    }

    if ($reportReady) {
        # Download the base64-encoded CSV report
        $reportResponse = Invoke-AWSAPI -Service iam -Command get-credential-report -ResourceName 'Credential Report' -ErrorAction Stop

        if ($reportResponse.Content) {
            $csvBytes = [System.Convert]::FromBase64String($reportResponse.Content)
            $csvText = [System.Text.Encoding]::UTF8.GetString($csvBytes)
            $data.CredentialReport = @($csvText | ConvertFrom-Csv)
            Write-CIEMLog -Severity DEBUG -Message "Credential report loaded: $($data.CredentialReport.Count) entries" -Component 'AWS-IAM'
        }
    } else {
        Write-Warning "Credential report generation timed out after ${maxWaitSeconds}s"
    }
}
catch {
    Write-Warning "Failed to load credential report: $($_.Exception.Message)"
}

# 2. Users
try {
    $usersResult = Invoke-AWSAPI -Service iam -Command list-users -ResourceName 'IAM Users' -Arguments @('--no-paginate') -ErrorAction Stop
    $data.Users = @($usersResult.Users)
    Write-CIEMLog -Severity DEBUG -Message "Users loaded: $($data.Users.Count)" -Component 'AWS-IAM'
}
catch {
    Write-Warning "Failed to load IAM users: $($_.Exception.Message)"
}

# 3. Password Policy
try {
    $policyResult = Invoke-AWSAPI -Service iam -Command get-account-password-policy -ResourceName 'Password Policy' -ErrorAction Stop
    $data.PasswordPolicy = $policyResult.PasswordPolicy
    Write-CIEMLog -Severity DEBUG -Message 'Password policy loaded' -Component 'AWS-IAM'
}
catch {
    # NoSuchEntity means no custom password policy is set - this is valid (not an error)
    if ($_.Exception.Message -match 'NoSuchEntity|not found') {
        Write-CIEMLog -Severity DEBUG -Message 'No custom password policy set (using AWS defaults)' -Component 'AWS-IAM'
    } else {
        Write-Warning "Failed to load password policy: $($_.Exception.Message)"
    }
}

# 4. Account Summary
try {
    $summaryResult = Invoke-AWSAPI -Service iam -Command get-account-summary -ResourceName 'Account Summary' -ErrorAction Stop
    $data.AccountSummary = $summaryResult.SummaryMap
    Write-CIEMLog -Severity DEBUG -Message 'Account summary loaded' -Component 'AWS-IAM'
}
catch {
    Write-Warning "Failed to load account summary: $($_.Exception.Message)"
}

# 5. Virtual MFA Devices
try {
    $mfaResult = Invoke-AWSAPI -Service iam -Command list-virtual-mfa-devices -ResourceName 'Virtual MFA Devices' -Arguments @('--no-paginate') -ErrorAction Stop
    $data.VirtualMFADevices = @($mfaResult.VirtualMFADevices)
    Write-CIEMLog -Severity DEBUG -Message "Virtual MFA devices loaded: $($data.VirtualMFADevices.Count)" -Component 'AWS-IAM'
}
catch {
    Write-Warning "Failed to load virtual MFA devices: $($_.Exception.Message)"
}

$data
