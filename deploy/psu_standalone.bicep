// PSU Standalone Deployment
// Deploys PowerShell Universal to Azure App Service
//
// Usage:
//   az deployment group create \
//     --resource-group devolutions-ciem-rg \
//     --template-file deploy/psu_standalone.bicep \
//     --parameters jwtSigningKey="$(openssl rand -base64 48)"

@description('Name of Azure Web App')
param siteName string = 'devolutions-ciem-psu'

@description('The version of PowerShell Universal')
param version string = '2026.1.5'

@description('App Service Plan Pricing Tier')
@allowed([
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1V2'
  'P2V2'
  'P2V3'
])
param servicePlanPricingTier string = 'S1'

@description('Location for all the resources.')
param location string = resourceGroup().location

@description('JWT Signing Key (must be 48+ characters)')
@secure()
param jwtSigningKey string

var servicePlanName = '${siteName}-asp'

var servicePlanPricingTiers = {
  B1: { tier: 'Basic' }
  B2: { tier: 'Basic' }
  B3: { tier: 'Basic' }
  S1: { tier: 'Standard' }
  S2: { tier: 'Standard' }
  S3: { tier: 'Standard' }
  P1V2: { tier: 'PremiumV2' }
  P2V2: { tier: 'PremiumV2' }
  P2V3: { tier: 'PremiumV3' }
}

resource servicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: servicePlanName
  location: location
  sku: {
    name: servicePlanPricingTier
    tier: servicePlanPricingTiers[servicePlanPricingTier].tier
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: siteName
  location: location
  properties: {
    serverFarmId: servicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|ironmansoftware/universal:${version}-azure'
      alwaysOn: servicePlanPricingTier != 'B1' && servicePlanPricingTier != 'B2' && servicePlanPricingTier != 'B3'
    }
  }
}

resource appSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: webApp
  name: 'appsettings'
  properties: {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'true'
    WEBSITES_CONTAINER_START_TIME_LIMIT: '1800'
    ASPNETCORE_FORWARDEDHEADERS_ENABLED: 'true'
    Jwt__SigningKey: jwtSigningKey
    Api__Url: 'https://${siteName}.azurewebsites.net'
    NodeName: siteName
  }
}

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output siteName string = siteName
output servicePlanId string = servicePlan.id
