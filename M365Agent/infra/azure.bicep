// Main Azure Infrastructure Orchestration
// This file orchestrates the deployment of:
// 1. User Managed Identity
// 2. App Service (with Managed Identity)
// 3. Bot Service (pointing to App Service)
// 4. Entra ID App Registration (using Bot MSI ID)

@maxLength(20)
@minLength(4)
@description('Used to generate names for all resources in this file')
param resourceBaseName string

@description('The SKU for the App Service Plan')
param webAppSKU string = 'B1'

@maxLength(42)
@description('Display name for the bot')
param botDisplayName string

@description('The name of the App Service Plan')
param serverfarmsName string = resourceBaseName

@description('The name of the Web App')
param webAppName string = resourceBaseName

@description('The name of the Managed Identity')
param identityName string = resourceBaseName

@description('The name of the Entra ID application')
param aadAppName string = '${resourceBaseName}-app'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Azure OpenAI API Key (optional)')
@secure()
param azureOpenAIApiKey string = ''

@description('Azure OpenAI Endpoint (optional)')
param azureOpenAIEndpoint string = ''

@description('Azure OpenAI Deployment Name (optional)')
param azureOpenAIDeploymentName string = ''

@description('Tenant ID')
param tenantId string = tenant().tenantId

// Step 1: Create User Managed Identity
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  location: location
  name: identityName
}

// Step 2: Create App Service using the Managed Identity
module appService './modules/appservice.bicep' = {
  name: 'appServiceDeployment'
  params: {
    resourceBaseName: resourceBaseName
    MSIid: identity.id
    location: location
    serverfarmsName: serverfarmsName
    webAppName: webAppName
    webAppSKU: webAppSKU
    enableAppInsights: false
    additionalAppSettings: [
      {
        name: 'RUNNING_ON_AZURE'
        value: '1'
      }
      {
        name: 'Connections__ServiceConnection__Settings__ClientId'
        value: identity.properties.clientId
      }
      {
        name: 'Connections__ServiceConnection__Settings__TenantId'
        value: identity.properties.tenantId
      }
      {
        name: 'TokenValidation__Audiences__0'
        value: identity.properties.clientId
      }
      {
        name: 'Azure__OpenAIApiKey'
        value: azureOpenAIApiKey
      }
      {
        name: 'Azure__OpenAIEndpoint'
        value: azureOpenAIEndpoint
      }
      {
        name: 'Azure__OpenAIDeploymentName'
        value: azureOpenAIDeploymentName
      }
    ]
  }
}

// Step 3: Create Bot Service pointing to the App Service URL
module azureBotRegistration './modules/azurebot.bicep' = {
  name: 'azureBotRegistration'
  params: {
    resourceBaseName: resourceBaseName
    identityClientId: identity.properties.clientId
    identityResourceId: identity.id
    identityTenantId: identity.properties.tenantId
    botAppDomain: appService.outputs.webAppHostName
    botDisplayName: botDisplayName
  }
}




// Step 4: Create Entra ID App Registration using the Bot MSI ID
module appRegistration './modules/app-registration.bicep' = {
  name: 'appRegistration'
  params: {
    aadAppName: aadAppName
    botId: identity.properties.clientId
    tenantId: tenantId
    fciSubject: 'system:serviceaccount:default:${resourceBaseName}'
  }
  dependsOn: [
    azureBotRegistration
  ]
}

// Outputs for downstream consumption (e.g., .env files, CI/CD pipelines)
output BOT_AZURE_APP_SERVICE_RESOURCE_ID string = appService.outputs.webAppId
output BOT_DOMAIN string = appService.outputs.webAppHostName
output BOT_ID string = identity.properties.clientId
output BOT_TENANT_ID string = identity.properties.tenantId
output MANAGED_IDENTITY_CLIENT_ID string = identity.properties.clientId
output MANAGED_IDENTITY_PRINCIPAL_ID string = identity.properties.principalId
output MANAGED_IDENTITY_RESOURCE_ID string = identity.id
output AAD_APP_CLIENT_ID string = appRegistration.outputs.aadAppId
output AAD_APP_OBJECT_ID string = appRegistration.outputs.aadAppObjectId
output AAD_APP_ID_URI string = appRegistration.outputs.aadAppIdUri
output WEB_APP_NAME string = appService.outputs.webAppName
output WEB_APP_URL string = 'https://${appService.outputs.webAppHostName}'
