[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$SubscriptionIds = @()
)

$ErrorActionPreference = 'Stop'

# Initialize service hashtable keyed by subscription
$data = @{}

if (-not $SubscriptionIds -or $SubscriptionIds.Count -eq 0) {
    # Nothing to process - script ends naturally
}
else {
    $armApiBase = (Get-CIEMProvider -Name 'Azure').Endpoints.armApi
    $webApiVersion = 'api-version=2023-01-01'
    $insightsApiVersion = 'api-version=2020-02-02'

    foreach ($subscriptionId in $SubscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading App Service resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            WebApps      = @()
            FunctionApps = @()
            SiteConfigs  = @{}
            AuthSettings = @{}
            FunctionKeys = @{}
            AppSettings  = @{}
            AppInsights  = @()
        }

        # Load all sites (web apps + function apps)
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Web/sites?$webApiVersion"
            ResourceName = "WebSites ($subscriptionId)"
        }
        $allSites = Invoke-AzureApi @params

        if ($allSites) {
            # Separate web apps from function apps based on kind property
            $webApps = @()
            $functionApps = @()

            foreach ($site in $allSites) {
                $kind = if ($site.PSObject.Properties['kind']) { $site.kind } else { 'app' }

                if ($kind -like 'functionapp*') {
                    $functionApps += $site
                }
                else {
                    $webApps += $site
                }
            }

            $data[$subscriptionId].WebApps = $webApps
            $data[$subscriptionId].FunctionApps = $functionApps

            # Load per-site sub-resources for web apps
            foreach ($app in $webApps) {
                $appName = $app.name
                $resourceGroup = ($app.id -split '/')[4]
                $baseUri = "$armApiBase/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$appName"

                # Site config (TLS, FTP, HTTP/2, runtime versions)
                $configParams = @{
                    Uri          = "$baseUri/config/web?$webApiVersion"
                    ResourceName = "SiteConfig ($appName)"
                }
                $data[$subscriptionId].SiteConfigs[$appName] = Invoke-AzureApi @configParams

                # Auth settings V2
                $authParams = @{
                    Uri          = "$baseUri/config/authsettingsV2?$webApiVersion"
                    ResourceName = "AuthSettings ($appName)"
                }
                $data[$subscriptionId].AuthSettings[$appName] = Invoke-AzureApi @authParams
            }

            # Load per-site sub-resources for function apps
            foreach ($func in $functionApps) {
                $funcName = $func.name
                $resourceGroup = ($func.id -split '/')[4]
                $baseUri = "$armApiBase/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$funcName"

                # Site config for function apps (ftps_state, etc.)
                $configParams = @{
                    Uri          = "$baseUri/config/web?$webApiVersion"
                    ResourceName = "SiteConfig ($funcName)"
                }
                $data[$subscriptionId].SiteConfigs[$funcName] = Invoke-AzureApi @configParams

                # Function host keys (POST action - use SilentlyContinue as access may be denied)
                $keysParams = @{
                    Uri          = "$baseUri/host/default/listkeys?$webApiVersion"
                    ResourceName = "FunctionKeys ($funcName)"
                }
                $keys = Invoke-AzureApi @keysParams -ErrorAction SilentlyContinue
                if ($keys) {
                    $data[$subscriptionId].FunctionKeys[$funcName] = $keys
                }
                else {
                    Write-CIEMLog -Severity DEBUG -Message "Cannot access host keys for function $funcName - access denied or not available"
                }

                # Application settings (environment variables)
                $settingsParams = @{
                    Uri          = "$baseUri/config/appsettings/list?$webApiVersion"
                    ResourceName = "AppSettings ($funcName)"
                }
                $settings = Invoke-AzureApi @settingsParams -ErrorAction SilentlyContinue
                if ($settings) {
                    $data[$subscriptionId].AppSettings[$funcName] = $settings
                }
                else {
                    Write-CIEMLog -Severity DEBUG -Message "Cannot access application settings for function $funcName - access denied or not available"
                }
            }

            Write-CIEMLog -Severity DEBUG -Message "App Service loaded for $subscriptionId : $($webApps.Count) web apps, $($functionApps.Count) function apps"
        }
        else {
            Write-CIEMLog -Severity DEBUG -Message "No Web Sites found in subscription $subscriptionId"
        }

        # Load Application Insights components (separate resource provider)
        $insightsParams = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Insights/components?$insightsApiVersion"
            ResourceName = "AppInsights ($subscriptionId)"
        }
        $components = Invoke-AzureApi @insightsParams
        if ($components) {
            $data[$subscriptionId].AppInsights = $components
            Write-CIEMLog -Severity DEBUG -Message "App Insights loaded for $subscriptionId : $($components.Count) components"
        }
        else {
            Write-CIEMLog -Severity DEBUG -Message "No Application Insights components found in subscription $subscriptionId"
        }
    }
}

$data
