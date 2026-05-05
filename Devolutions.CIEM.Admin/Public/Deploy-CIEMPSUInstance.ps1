function Deploy-CIEMPSUInstance {
    <#
    .SYNOPSIS
        Deploys the Azure PowerShell Universal host used by CIEM.

    .DESCRIPTION
        Creates the Azure resource group, deploys the PSU App Service from the
        repo Bicep template, and waits until the PSU alive endpoint reports ready.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string]$ResourceGroup = 'devolutions-ciem-rg',

        [Parameter()]
        [string]$SiteName = 'devolutions-ciem-psu',

        [Parameter()]
        [string]$Location = 'westus2',

        [Parameter()]
        [string]$ServicePlanPricingTier = 'S1',

        [Parameter()]
        [string]$PsuVersion = '5.5.4',

        [Parameter()]
        [string]$TemplatePath = (Join-Path -Path $script:RepoRoot -ChildPath 'deploy/psu_standalone.bicep'),

        [Parameter()]
        [int]$TimeoutSeconds = 300,

        [Parameter()]
        [int]$PollIntervalSeconds = 10
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path -Path $TemplatePath -PathType Leaf)) {
        throw "PSU Bicep template not found: $TemplatePath"
    }

    $accountName = @(Invoke-CIEMAzCommand -ArgumentList @('account', 'show', '--query', 'name', '-o', 'tsv')) -join "`n"
    if ([string]::IsNullOrWhiteSpace([string]$accountName)) {
        throw 'Azure CLI returned an empty account name. Run az login before Deploy-CIEMPSUInstance.'
    }

    Invoke-CIEMAzCommand -ArgumentList @('group', 'create', '--name', $ResourceGroup, '--location', $Location, '-o', 'none') | Out-Null

    $jwtBytes = [byte[]]::new(48)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($jwtBytes)
    $jwtSigningKey = [Convert]::ToBase64String($jwtBytes)

    Invoke-CIEMAzCommand -ArgumentList @(
        'deployment'
        'group'
        'create'
        '--resource-group'
        $ResourceGroup
        '--template-file'
        $TemplatePath
        '--parameters'
        "siteName=$SiteName"
        "version=$PsuVersion"
        "servicePlanPricingTier=$ServicePlanPricingTier"
        "jwtSigningKey=$jwtSigningKey"
        '-o'
        'none'
    ) | Out-Null

    $appUrl = "https://$SiteName.azurewebsites.net"
    $aliveUrl = "$appUrl/api/v1/alive"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastStatus = $null

    do {
        try {
            $response = Invoke-RestMethod -Uri $aliveUrl -Headers @{ 'ngrok-skip-browser-warning' = 'true' } -Method Get -TimeoutSec 10 -ErrorAction Stop
            $lastStatus = "loading=$($response.loading); hasError=$($response.hasError); loadingInfo=$($response.loadingInfo)"
            if ($response.loading -eq $false -and $response.hasError -eq $false) {
                return [pscustomobject]@{
                    Status                 = 'Ready'
                    Url                    = $appUrl
                    ResourceGroup          = $ResourceGroup
                    SiteName               = $SiteName
                    Location               = $Location
                    ServicePlanPricingTier = $ServicePlanPricingTier
                    PsuVersion             = $PsuVersion
                    AzureAccount           = [string]$accountName
                    Alive                  = $response
                }
            }
        }
        catch {
            $lastStatus = "RequestFailed: $_"
        }

        if ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds $PollIntervalSeconds
        }
    } while ((Get-Date) -lt $deadline)

    throw "PSU alive endpoint did not report loading=false and hasError=false within $TimeoutSeconds seconds. Last status: $lastStatus. URL: $aliveUrl"
}
