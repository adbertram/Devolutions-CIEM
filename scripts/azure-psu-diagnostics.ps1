[CmdletBinding()]
param(
    [Parameter()]
    [string]$ResourceGroup = 'devolutions-ciem-rg',

    [Parameter()]
    [string]$WebAppName = 'devolutions-ciem-psu',

    [Parameter()]
    [int]$JobLimit = 15,

    [Parameter()]
    [int]$LogLineCount = 40,

    [Parameter()]
    [int]$AzureCliTimeoutSeconds = 1800,

    [Parameter()]
    [int]$ArmTimeoutSeconds = 1800,

    [Parameter()]
    [int]$KuduTimeoutSeconds = 1800,

    [Parameter()]
    [int]$RuntimeProbeTimeoutSeconds = 300,

    [Parameter()]
    [string]$LogPath,

    [Parameter()]
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$adminManifest = Join-Path $projectRoot 'Devolutions.CIEM.Admin' 'Devolutions.CIEM.Admin.psd1'
$tempDirectory = Join-Path $projectRoot '_temp'

if (-not $LogPath) {
    $LogPath = Join-Path $tempDirectory 'azure-psu-diagnostics.log'
}

New-Item -ItemType Directory -Path $tempDirectory -Force | Out-Null
if (Test-Path $LogPath) {
    Remove-Item $LogPath -Force
}

Import-Module $adminManifest -Force
Start-Transcript -Path $LogPath -Force | Out-Null

function Invoke-DiagnosticStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [ValidateSet('AzureControlPlane', 'KuduControlPlane', 'PSURuntime', 'Unknown')]
        [string]$FailurePlane = 'Unknown'
    )

    $ErrorActionPreference = 'Stop'

    try {
        [pscustomobject]@{
            Name         = $Name
            Ok           = $true
            FailurePlane = $FailurePlane
            Data         = & $ScriptBlock
        }
    }
    catch {
        $httpFailure = Get-HttpFailureDetail -ErrorRecord $_
        [pscustomobject]@{
            Name           = $Name
            Ok             = $false
            FailurePlane   = $FailurePlane
            Classification = Get-FailureClassification -FailurePlane $FailurePlane
            Error          = $_.Exception.Message
            Http           = $httpFailure
        }
    }
}

function Get-FailureClassification {
    param(
        [Parameter(Mandatory)]
        [string]$FailurePlane
    )

    $ErrorActionPreference = 'Stop'

    switch ($FailurePlane) {
        'AzureControlPlane' { 'AzureControlPlaneUnavailable' }
        'KuduControlPlane' { 'AzureControlPlaneUnavailable' }
        'PSURuntime' { 'PSUAppUnhealthy' }
        default { 'UnknownFailure' }
    }
}

function Get-HttpFailureDetail {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $ErrorActionPreference = 'Stop'

    $response = $null
    if ($ErrorRecord.Exception.PSObject.Properties.Name -contains 'Response') {
        $response = $ErrorRecord.Exception.Response
    }
    elseif ($ErrorRecord.Exception.InnerException -and $ErrorRecord.Exception.InnerException.PSObject.Properties.Name -contains 'Response') {
        $response = $ErrorRecord.Exception.InnerException.Response
    }

    $detail = [ordered]@{
        ExceptionType = $ErrorRecord.Exception.GetType().FullName
        Message       = $ErrorRecord.Exception.Message
    }

    if (-not $response) {
        return [pscustomobject]$detail
    }

    try {
        $detail.StatusCode = [int]$response.StatusCode
    }
    catch {
    }

    try {
        if ($response.ReasonPhrase) {
            $detail.ReasonPhrase = $response.ReasonPhrase
        }
    }
    catch {
    }

    try {
        if ($response.Content) {
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if (-not [string]::IsNullOrWhiteSpace($body)) {
                if ($body.Length -gt 4000) {
                    $body = $body.Substring(0, 4000)
                }
                $detail.ResponseBody = $body
            }
        }
    }
    catch {
    }

    [pscustomobject]$detail
}

function Invoke-AzJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $ErrorActionPreference = 'Stop'

    $timeoutExe = Get-Command timeout -ErrorAction Stop
    $output = & $timeoutExe.Source $AzureCliTimeoutSeconds az @Arguments 2>&1
    if ($LASTEXITCODE -eq 124) {
        throw "Azure CLI timed out: az $($Arguments -join ' ')"
    }
    if ($LASTEXITCODE -ne 0) {
        throw (($output | Out-String).Trim())
    }

    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    $text | ConvertFrom-Json -Depth 100
}

function Get-AzAccessToken {
    $ErrorActionPreference = 'Stop'

    $tokenResponse = Invoke-AzJson -Arguments @(
        'account', 'get-access-token',
        '--resource', 'https://management.azure.com/',
        '-o', 'json'
    )

    $tokenResponse.accessToken
}

function Get-AzSubscriptionId {
    $ErrorActionPreference = 'Stop'

    $account = Invoke-AzJson -Arguments @(
        'account', 'show',
        '-o', 'json'
    )

    $account.id
}

function Invoke-AzArmJson {
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [Parameter(Mandatory)]
        [string]$AccessToken,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$Method = 'Get',

        [Parameter()]
        [object]$Body
    )

    $ErrorActionPreference = 'Stop'

    $baseUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$WebAppName"
    if ($Path.StartsWith('?')) {
        $uri = "$baseUri$Path"
    }
    else {
        $uri = "$baseUri/$Path"
    }

    $requestSplat = @{
        Uri         = $uri
        Method      = $Method
        Headers     = @{
            Authorization = "Bearer $AccessToken"
        }
        TimeoutSec  = $ArmTimeoutSeconds
        ErrorAction = 'Stop'
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $requestSplat.ContentType = 'application/json'
        $requestSplat.Body = ($Body | ConvertTo-Json -Depth 20 -Compress)
    }

    Invoke-RestMethod @requestSplat
}

function Get-KuduCredential {
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $ErrorActionPreference = 'Stop'

    $creds = Invoke-AzArmJson -SubscriptionId $SubscriptionId -AccessToken $AccessToken -Path 'config/publishingcredentials/list?api-version=2023-12-01' -Method Post -Body @{}

    [pscustomobject]@{
        UserName = $creds.publishingUserName
        Password = $creds.publishingPassword
    }
}

function Invoke-KuduCommand {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Credential,

        [Parameter(Mandatory)]
        [string]$Command
    )

    $ErrorActionPreference = 'Stop'

    $uri = "https://${WebAppName}.scm.azurewebsites.net/api/command"
    $pair = '{0}:{1}' -f $Credential.UserName, $Credential.Password
    $authBytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $authValue = [Convert]::ToBase64String($authBytes)

    $payload = @{
        command = "bash -lc ""$Command"""
        dir     = '/home'
    } | ConvertTo-Json -Compress

    Invoke-RestMethod -Uri $uri -Method Post -Headers @{
        Authorization = "Basic $authValue"
        'Content-Type' = 'application/json'
    } -Body $payload -TimeoutSec $KuduTimeoutSeconds
}

function Invoke-KuduGet {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Credential,

        [Parameter(Mandatory)]
        [string]$Uri
    )

    $ErrorActionPreference = 'Stop'

    $pair = '{0}:{1}' -f $Credential.UserName, $Credential.Password
    $authBytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $authValue = [Convert]::ToBase64String($authBytes)

    Invoke-RestMethod -Uri $Uri -Method Get -Headers @{
        Authorization = "Basic $authValue"
    } -TimeoutSec $KuduTimeoutSeconds
}

function Convert-AliveResult {
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    $ErrorActionPreference = 'Stop'

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-WebRequest -Uri "$Url/api/v1/alive" -Method Get
    $stopwatch.Stop()

    $body = $response.Content | ConvertFrom-Json -Depth 20

    [pscustomobject]@{
        StatusCode      = [int]$response.StatusCode
        ResponseMs      = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
        Loading         = $body.loading
        LoadingInfo     = $body.loadingInfo
        RawContentType  = $response.Headers.'Content-Type'
    }
}

function Select-RecentLogLines {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Credential,

        [Parameter(Mandatory)]
        [int]$LineCount
    )

    $ErrorActionPreference = 'Stop'

    $command = @"
find /home/LogFiles -type f 2>/dev/null | sort | tail -n 3 | while read -r file; do
  echo "--- ${file} ---"
  tail -n ${LineCount} "${file}" 2>/dev/null
  echo
done
"@

    $result = Invoke-KuduCommand -Credential $Credential -Command $command
    ($result.Output | Out-String).Trim()
}

function Get-SectionValue {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Section
    )

    $ErrorActionPreference = 'Stop'

    if ($Section.Ok) {
        return $Section.Data
    }

    $failure = [ordered]@{
        Error          = $Section.Error
        FailurePlane   = $Section.FailurePlane
        Classification = $Section.Classification
    }

    if ($Section.Http) {
        $failure.Http = $Section.Http
    }

    [pscustomobject]$failure
}

try {
    $connection = Connect-PSU -ResourceGroup $ResourceGroup -WebAppName $WebAppName
    $baseUrl = $connection.Url.TrimEnd('/')
    $subscriptionId = Get-AzSubscriptionId
    $armAccessToken = Get-AzAccessToken

    $alive = Invoke-DiagnosticStep -Name 'Alive' -FailurePlane 'PSURuntime' -ScriptBlock {
        Convert-AliveResult -Url $baseUrl
    }

    $webApp = Invoke-DiagnosticStep -Name 'WebApp' -FailurePlane 'AzureControlPlane' -ScriptBlock {
        $site = Invoke-AzArmJson -SubscriptionId $subscriptionId -AccessToken $armAccessToken -Path '?api-version=2023-12-01'
        $site.properties | Select-Object state, availabilityState, enabled, usageState, defaultHostName, hostNames
    }

    $instances = Invoke-DiagnosticStep -Name 'Instances' -FailurePlane 'AzureControlPlane' -ScriptBlock {
        @(Invoke-AzArmJson -SubscriptionId $subscriptionId -AccessToken $armAccessToken -Path 'instances?api-version=2023-12-01').value |
            Select-Object name, @{
                Name       = 'state'
                Expression = { $_.properties.state }
            }, @{
                Name       = 'statusUrl'
                Expression = { $_.properties.statusUrl }
            }, @{
                Name       = 'detectorUrl'
                Expression = { $_.properties.detectorUrl }
            }
    }

    $instanceStatus = Invoke-DiagnosticStep -Name 'InstanceStatus' -FailurePlane 'KuduControlPlane' -ScriptBlock {
        $instanceRows = @()
        $kuduCredential = Get-KuduCredential -SubscriptionId $subscriptionId -AccessToken $armAccessToken
        foreach ($instance in (Get-SectionValue -Section $instances)) {
            if ($instance.PSObject.Properties.Name -contains 'Error') {
                throw $instance.Error
            }

            if (-not $instance.statusUrl) {
                continue
            }

            $status = Invoke-KuduGet -Credential $kuduCredential -Uri $instance.statusUrl
            $instanceRows += [pscustomobject]@{
                Name               = $instance.name
                State              = $instance.state
                Status             = $status.Status
                Details            = $status.Details
                FailedInstances    = $status.FailedInstances
                RuntimeUnavailable = $status.RuntimeUnavailable
            }
        }

        $instanceRows
    }

    $linuxFxVersion = Invoke-DiagnosticStep -Name 'LinuxFxVersion' -FailurePlane 'AzureControlPlane' -ScriptBlock {
        Invoke-AzArmJson -SubscriptionId $subscriptionId -AccessToken $armAccessToken -Path 'config/web?api-version=2023-12-01' |
            Select-Object -ExpandProperty properties |
            Select-Object -ExpandProperty linuxFxVersion
    }

    $appSettings = Invoke-DiagnosticStep -Name 'AppSettings' -FailurePlane 'AzureControlPlane' -ScriptBlock {
        $settingsResponse = Invoke-AzArmJson -SubscriptionId $subscriptionId -AccessToken $armAccessToken -Path 'config/appsettings/list?api-version=2023-12-01' -Method Post -Body @{}
        $settings = @()
        foreach ($property in $settingsResponse.properties.PSObject.Properties) {
            $settings += [pscustomobject]@{
                Name  = $property.Name
                Value = $property.Value
            }
        }

        $settingNames = @($settings.Name | Sort-Object)
        $securityModel = ($settings | Where-Object Name -eq 'API__SecurityModel' | Select-Object -First 1).Value

        [pscustomobject]@{
            SecurityModel = $securityModel
            SettingNames  = $settingNames
        }
    }

    $psuVersion = Invoke-DiagnosticStep -Name 'PSUVersion' -FailurePlane 'PSURuntime' -ScriptBlock {
        if (Get-Command Get-PSUInformation -ErrorAction SilentlyContinue) {
            Get-PSUInformation | Select-Object Version
        }
        else {
            Invoke-RestMethod -Uri "$baseUrl/api/v1/version" -Method Get
        }
    }

    $ciemApp = Invoke-DiagnosticStep -Name 'CIEMApp' -FailurePlane 'PSURuntime' -ScriptBlock {
        @(Get-PSUApp) |
            Where-Object { $_.Name -eq 'Devolutions CIEM' } |
            Select-Object id, name, baseUrl, framework
    }

    $ciemModule = Invoke-DiagnosticStep -Name 'CIEMModule' -FailurePlane 'PSURuntime' -ScriptBlock {
        @(Get-PSUModule -Name 'Devolutions.CIEM') |
            Sort-Object version -Descending |
            Select-Object name, version, path
    }

    $appTokens = Invoke-DiagnosticStep -Name 'AppTokens' -FailurePlane 'PSURuntime' -ScriptBlock {
        $tokens = @(Get-PSUAppToken)

        [pscustomobject]@{
            Count = $tokens.Count
            Items = @($tokens | Select-Object id, expirationDate, revoked, grantedTo)
        }
    }

    $runtimeProbe = Invoke-DiagnosticStep -Name 'RuntimeProbe' -FailurePlane 'PSURuntime' -ScriptBlock {
        $runtimeScript = @"
`$moduleInfo = Get-Module Devolutions.CIEM | Select-Object Name, Version, Path
`$installedEnvironment = Get-PSUInstalledEnvironment
`$profiles = @(Get-CIEMAzureAuthenticationProfile) | Select-Object Id, Name, Method, IsActive, TenantId, ClientId
`$activeProfile = `$profiles | Where-Object IsActive | Select-Object -First 1
`$variableNames = @(
    @(Get-PSUVariable | Where-Object Name -like 'CIEM_Azure*' | Select-Object -ExpandProperty Name)
    @(Get-PSUVariable -Name 'azure-sp-cert_CertPfx' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
) | Sort-Object -Unique
`$jobs = @(Get-PSUJob -First $JobLimit -OrderDirection Descending -HideChildren `$true -HideScheduled `$true -HideTriggered `$true) |
    Select-Object Id, Script, Status, StartTime, EndTime, Duration, HasErrors, HasWarnings

[pscustomobject]@{
    InstalledEnvironment = `$installedEnvironment
    Module               = `$moduleInfo
    AuthProfiles         = `$profiles
    ActiveProfile        = `$activeProfile
    VariableNames        = `$variableNames
    JobStatusCounts      = @(`$jobs | Group-Object Status | Sort-Object Name | Select-Object Name, Count)
    Jobs                 = `$jobs
} | ConvertTo-Json -Depth 10 -Compress
"@

        $probe = Invoke-TestCommand -Environment azure -TimeoutSeconds $RuntimeProbeTimeoutSeconds -ScriptBlock ([scriptblock]::Create($runtimeScript))
        $outputText = @($probe.Output | ForEach-Object {
            if ($_ -is [string]) {
                $_
            }
            elseif ($_.message) {
                $_.message
            }
            elseif ($_.data) {
                $_.data
            }
        }) -join "`n"

        $jsonLine = @($outputText -split "`r?`n" | Where-Object { $_ -match '^\s*[\{\[]' }) | Select-Object -Last 1
        if (-not $jsonLine) {
            throw 'Runtime probe did not return JSON output.'
        }

        $jsonLine | ConvertFrom-Json -Depth 20
    }

    $logExcerpts = Invoke-DiagnosticStep -Name 'LogExcerpts' -FailurePlane 'KuduControlPlane' -ScriptBlock {
        $kuduCredential = Get-KuduCredential -SubscriptionId $subscriptionId -AccessToken $armAccessToken
        Select-RecentLogLines -Credential $kuduCredential -LineCount $LogLineCount
    }

    $sections = @(
        $alive,
        $webApp,
        $instances,
        $instanceStatus,
        $linuxFxVersion,
        $appSettings,
        $psuVersion,
        $ciemApp,
        $ciemModule,
        $appTokens,
        $runtimeProbe,
        $logExcerpts
    )

    $failureSummary = [pscustomobject]@{
        AzureControlPlaneUnavailable = @(
            $sections |
                Where-Object { -not $_.Ok -and $_.FailurePlane -in @('AzureControlPlane', 'KuduControlPlane') } |
                ForEach-Object { $_.Name }
        )
        PSUAppUnhealthy = @(
            $sections |
                Where-Object { -not $_.Ok -and $_.FailurePlane -eq 'PSURuntime' } |
                ForEach-Object { $_.Name }
        )
    }

    $report = [pscustomobject]@{
        GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        LogPath        = $LogPath
        Target         = [pscustomobject]@{
            Url           = $baseUrl
            ResourceGroup = $ResourceGroup
            WebAppName    = $WebAppName
        }
        Alive          = Get-SectionValue -Section $alive
        WebApp         = Get-SectionValue -Section $webApp
        Instances      = Get-SectionValue -Section $instances
        InstanceStatus = Get-SectionValue -Section $instanceStatus
        LinuxFxVersion = Get-SectionValue -Section $linuxFxVersion
        AppSettings    = Get-SectionValue -Section $appSettings
        PSUVersion     = Get-SectionValue -Section $psuVersion
        CIEMApp        = Get-SectionValue -Section $ciemApp
        CIEMModule     = Get-SectionValue -Section $ciemModule
        AppTokens      = Get-SectionValue -Section $appTokens
        Runtime        = Get-SectionValue -Section $runtimeProbe
        LogExcerpts    = Get-SectionValue -Section $logExcerpts
        FailureSummary = $failureSummary
    }

    if ($Json) {
        $report | ConvertTo-Json -Depth 20
    }
    else {
        $report
    }
}
finally {
    Stop-Transcript | Out-Null
}
