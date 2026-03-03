// Prowler On-Demand Deployment
// Deploys Prowler CLI as an Azure Container Instance for on-demand scanning
//
// Usage:
//   # Deploy the ACI template (creates container group that can be started/stopped)
//   az deployment group create \
//     --resource-group devolutions-ciem-rg \
//     --template-file deploy/prowler.bicep \
//     --parameters azureSubscriptionId="<subscription-id>"
//
//   # To run a scan, start the container:
//   az container start --resource-group devolutions-ciem-rg --name prowler-scanner
//
//   # Check logs:
//   az container logs --resource-group devolutions-ciem-rg --name prowler-scanner
//
//   # Stop when done:
//   az container stop --resource-group devolutions-ciem-rg --name prowler-scanner

@description('Name of the container instance')
param containerName string = 'prowler-scanner'

@description('Location for all the resources.')
param location string = resourceGroup().location

@description('Prowler container image')
param prowlerImage string = 'prowlercloud/prowler:latest'

@description('CPU cores for the container')
param cpuCores int = 2

@description('Memory in GB for the container')
param memoryInGb int = 4

@description('Azure Subscription ID to scan')
param azureSubscriptionId string = ''

@description('Cloud provider to scan')
@allowed([
  'azure'
  'aws'
  'gcp'
  'kubernetes'
])
param provider string = 'azure'

@description('Output format')
@allowed([
  'json'
  'csv'
  'html'
  'json-ocsf'
])
param outputFormat string = 'json'

@description('Storage account name for scan results (optional)')
param storageAccountName string = ''

@description('Enable managed identity for Azure scanning')
param enableManagedIdentity bool = true

// User-assigned managed identity for Prowler to access Azure resources
resource prowlerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (enableManagedIdentity) {
  name: '${containerName}-identity'
  location: location
}

// Storage account for scan results (optional)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = if (!empty(storageAccountName)) {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = if (!empty(storageAccountName)) {
  parent: storageAccount
  name: 'default'
}

resource resultsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = if (!empty(storageAccountName)) {
  parent: blobService
  name: 'prowler-results'
  properties: {
    publicAccess: 'None'
  }
}

// Container instance for Prowler
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerName
  location: location
  identity: enableManagedIdentity ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${prowlerIdentity.id}': {}
    }
  } : null
  properties: {
    containers: [
      {
        name: 'prowler'
        properties: {
          image: prowlerImage
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          command: [
            'prowler'
            provider
            '-M'
            outputFormat
            '--output-directory'
            '/output'
          ]
          environmentVariables: [
            {
              name: 'AZURE_SUBSCRIPTION_ID'
              value: azureSubscriptionId
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
        emptyDir: {}
      }
    ]
  }
}

output containerGroupId string = containerGroup.id
output containerGroupName string = containerGroup.name
output identityPrincipalId string = enableManagedIdentity ? prowlerIdentity.properties.principalId : ''
output identityClientId string = enableManagedIdentity ? prowlerIdentity.properties.clientId : ''

// Instructions for granting access
output postDeploymentInstructions string = '''
After deployment, grant the managed identity read access to scan Azure resources:

  # Grant Reader role on subscription
  az role assignment create \
    --assignee <identityPrincipalId> \
    --role "Reader" \
    --scope "/subscriptions/<subscription-id>"

  # For security-specific checks, also grant:
  az role assignment create \
    --assignee <identityPrincipalId> \
    --role "Security Reader" \
    --scope "/subscriptions/<subscription-id>"

Then start a scan:
  az container start --resource-group devolutions-ciem-rg --name prowler-scanner
  az container logs --resource-group devolutions-ciem-rg --name prowler-scanner --follow
'''
