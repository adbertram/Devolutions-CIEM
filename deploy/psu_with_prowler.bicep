// PSU with Prowler Deployment
// Deploys PowerShell Universal + Prowler ACI that PSU can invoke
//
// Usage:
//   az deployment group create \
//     --resource-group devolutions-ciem-rg \
//     --template-file deploy/psu_with_prowler.bicep \
//     --parameters jwtSigningKey="$(openssl rand -base64 48)" \
//                  azureSubscriptionId="<subscription-id>"

@description('Name of Azure Web App for PSU')
param psuSiteName string = 'devolutions-ciem-psu'

@description('Name of the Prowler container instance')
param prowlerContainerName string = 'prowler-scanner'

@description('The version of PowerShell Universal')
param psuVersion string = '5.4.4'

@description('Prowler container image')
param prowlerImage string = 'prowlercloud/prowler:latest'

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

@description('JWT Signing Key for PSU (must be 48+ characters)')
@secure()
param jwtSigningKey string

@description('Azure Subscription ID to scan')
param azureSubscriptionId string

@description('Storage account name for scan results')
param storageAccountName string = 'dvlciemresults${uniqueString(resourceGroup().id)}'

// ============================================================================
// SHARED RESOURCES
// ============================================================================

var servicePlanName = '${psuSiteName}-asp'

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

// Storage account for scan results
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource resultsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'prowler-results'
  properties: {
    publicAccess: 'None'
  }
}

// ============================================================================
// PSU RESOURCES
// ============================================================================

// Managed identity for PSU to manage ACI and access storage
resource psuIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${psuSiteName}-identity'
  location: location
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

resource psuWebApp 'Microsoft.Web/sites@2024-04-01' = {
  name: psuSiteName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${psuIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: servicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|ironmansoftware/universal:${psuVersion}-azure'
      alwaysOn: servicePlanPricingTier != 'B1' && servicePlanPricingTier != 'B2' && servicePlanPricingTier != 'B3'
    }
  }
}

resource psuAppSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: psuWebApp
  name: 'appsettings'
  properties: {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'true'
    ASPNETCORE_FORWARDEDHEADERS_ENABLED: 'true'
    Jwt__SigningKey: jwtSigningKey
    Api__Url: 'https://${psuSiteName}.azurewebsites.net'
    NodeName: psuSiteName
    // Prowler integration settings
    PROWLER_CONTAINER_NAME: prowlerContainerName
    PROWLER_RESOURCE_GROUP: resourceGroup().name
    PROWLER_STORAGE_ACCOUNT: storageAccountName
    PROWLER_STORAGE_CONTAINER: 'prowler-results'
    AZURE_SUBSCRIPTION_ID: azureSubscriptionId
    AZURE_CLIENT_ID: psuIdentity.properties.clientId
  }
}

// ============================================================================
// PROWLER RESOURCES
// ============================================================================

// Managed identity for Prowler to scan Azure resources
resource prowlerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prowlerContainerName}-identity'
  location: location
}

// Container instance for Prowler (starts in stopped state)
resource prowlerContainer 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: prowlerContainerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${prowlerIdentity.id}': {}
    }
  }
  properties: {
    containers: [
      {
        name: 'prowler'
        properties: {
          image: prowlerImage
          resources: {
            requests: {
              cpu: 2
              memoryInGB: 4
            }
          }
          command: [
            'prowler'
            'azure'
            '-M'
            'json'
            '--output-directory'
            '/output'
            '--sp-env-auth'
          ]
          environmentVariables: [
            {
              name: 'AZURE_SUBSCRIPTION_ID'
              value: azureSubscriptionId
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: prowlerIdentity.properties.clientId
            }
          ]
          volumeMounts: [
            {
              name: 'output'
              mountPath: '/output'
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Never'
    volumes: [
      {
        name: 'output'
        azureFile: {
          shareName: 'prowler-output'
          storageAccountName: storageAccountName
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
      }
    ]
  }
}

// ============================================================================
// ROLE ASSIGNMENTS
// ============================================================================

// PSU identity needs Contributor on the ACI to start/stop it
resource psuAciContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, psuIdentity.id, 'aci-contributor')
  scope: prowlerContainer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: psuIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// PSU identity needs Storage Blob Data Contributor to read results
resource psuStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, psuIdentity.id, 'storage-contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: psuIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

output psuUrl string = 'https://${psuWebApp.properties.defaultHostName}'
output psuSiteName string = psuSiteName
output prowlerContainerName string = prowlerContainerName
output storageAccountName string = storageAccountName
output psuIdentityPrincipalId string = psuIdentity.properties.principalId
output prowlerIdentityPrincipalId string = prowlerIdentity.properties.principalId

output postDeploymentInstructions string = '''
After deployment, grant the Prowler identity read access to scan Azure resources:

  # Get the Prowler identity principal ID from outputs
  PROWLER_PRINCIPAL_ID=$(az deployment group show \
    --resource-group devolutions-ciem-rg \
    --name <deployment-name> \
    --query properties.outputs.prowlerIdentityPrincipalId.value -o tsv)

  # Grant Reader role on subscription
  az role assignment create \
    --assignee $PROWLER_PRINCIPAL_ID \
    --role "Reader" \
    --scope "/subscriptions/<subscription-id>"

  # Grant Security Reader role
  az role assignment create \
    --assignee $PROWLER_PRINCIPAL_ID \
    --role "Security Reader" \
    --scope "/subscriptions/<subscription-id>"

Then from PSU, use the following PowerShell to trigger scans:

  # Start a scan
  az container start --resource-group $env:PROWLER_RESOURCE_GROUP --name $env:PROWLER_CONTAINER_NAME

  # Check status
  az container show --resource-group $env:PROWLER_RESOURCE_GROUP --name $env:PROWLER_CONTAINER_NAME --query instanceView.state

  # Get logs
  az container logs --resource-group $env:PROWLER_RESOURCE_GROUP --name $env:PROWLER_CONTAINER_NAME
'''
