@description('Name of Azure Web App')
param siteName string = 'devolutions-ciem-psu'

@description('The version of PowerShell Universal')
param version string = '5.4.4'

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
param servicePlanPricingTier string = 'B1'
var servicePlanName = '${siteName}-asp'

@description('Location for all the resources.')
param location string = resourceGroup().location

@description('JWT Signing Key (must be 48+ characters)')
@secure()
param jwtSigningKey string

var servicePlanPricingTiers = {
  B1: {
    tier: 'Basic'
  }
  B2: {
    tier: 'Basic'
  }
  B3: {
    tier: 'Basic'
  }
  S1: {
    tier: 'Standard'
  }
  S2: {
    tier: 'Standard'
  }
  S3: {
    tier: 'Standard'
  }
  P1V2: {
    tier: 'Standard'
  }
  P2V2: {
    tier: 'Standard'
  }
  P2V3: {
    tier: 'Standard'
  }
}

resource planResource 'Microsoft.Web/serverfarms@2024-04-01' = {
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

resource siteResource 'Microsoft.Web/sites@2024-04-01' = {
  name: siteName
  location: location
  properties: {
    serverFarmId: planResource.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|ironmansoftware/universal:${version}-azure'
    }
  }
}

resource siteWebAppsettingsResource 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: siteResource
  name: 'appsettings'
  properties: {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'true'
    ASPNETCORE_FORWARDEDHEADERS_ENABLED: 'true'
    Jwt__SigningKey: jwtSigningKey
    Api__Url: 'https://${siteName}.azurewebsites.net'
    NodeName: siteName
  }
}

output webAppUrl string = 'https://${siteResource.properties.defaultHostName}'
output siteName string = siteName
