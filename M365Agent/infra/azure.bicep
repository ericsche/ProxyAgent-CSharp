// Main orchestration file for M365 Agent deployment
// This deploys: Managed Identity → App Service → Azure Bot → App Registration

targetScope = 'resourceGroup'

@maxLength(20)
@minLength(4)
@description('Used to generate names for all resources')
param resourceBaseName string

@maxLength(42)
@description('Display name for the bot')
param botDisplayName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('The SKU for the App Service Plan')
@allowed([
  'F1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
])
param webAppSKU string = 'B1'

@description('The SKU for the Bot Service')
@allowed([
  'F0'
  'S1'
])
param botServiceSku string = 'F0'

@description('Tenant ID for the Entra ID application')
param tenantId string = tenant().tenantId

@description('Enable Application Insights')
param enableAppInsights bool = false

@description('Application Insights instrumentation key (optional)')
param appInsightsInstrumentationKey string = ''

@description('Application Insights connection string (optional)')
param appInsightsConnectionString string = ''

@description('Additional app settings for the Web App')
param additionalAppSettings array = []

// Generate resource names
var identityName = '${resourceBaseName}-identity'
var webAppName = '${resourceBaseName}-app'
var botServiceName = '${resourceBaseName}-bot'
var aadAppName = '${resourceBaseName}-app-registration'

// Step 1: Create User Assigned Managed Identity for the bot
module botIdentity 'modules/bot-managedidentity.bicep' = {
  name: 'deploy-bot-identity'
  params: {
    identityName: identityName
    location: location
  }
}

// Step 2: Create App Service with the managed identity
module appService 'modules/appservice.bicep' = {
  name: 'deploy-app-service'
  params: {
    resourceBaseName: resourceBaseName
    location: location
    serverfarmsName: '${resourceBaseName}-plan'
    webAppName: webAppName
    webAppSKU: webAppSKU
    MSIid: botIdentity.outputs.identityId
    enableAppInsights: enableAppInsights
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsConnectionString: appInsightsConnectionString
    additionalAppSettings: additionalAppSettings
  }
}

// Step 3: Create Azure Bot Service
module azureBot 'modules/azurebot.bicep' = {
  name: 'deploy-azure-bot'
  params: {
    resourceBaseName: resourceBaseName
    botDisplayName: botDisplayName
    botServiceName: botServiceName
    botServiceSku: botServiceSku
    identityResourceId: botIdentity.outputs.identityId
    identityClientId: botIdentity.outputs.identityClientId
    identityTenantId: tenantId
    botAppDomain: appService.outputs.webAppHostName
  }
}

// Step 4: Create App Registration with all required parameters
module appRegistration 'modules/app-registration.bicep' = {
  name: 'deploy-app-registration'
  params: {
    aadAppName: aadAppName
    botId: botIdentity.outputs.identityClientId
    tenantId: tenantId
    location: location
  }
  dependsOn: [
    azureBot
  ]
}

// Step 5: Configure OAuth Connection with Azure AD v2 and Federated Credentials
module botOAuthConnection 'modules/bot-oauth-connection.bicep' = {
  name: 'deploy-bot-oauth-connection'
  params: {
    botServiceName: botServiceName
    connectionName: 'SsoConnection'
    aadAppId: appRegistration.outputs.aadAppId
    aadAppIdUri: appRegistration.outputs.aadAppIdUri
    federatedCredentialSubject: appRegistration.outputs.fciName
    scopes: '${appRegistration.outputs.aadAppIdUri}/access_as_user'
    tenantId: tenantId
    location: 'global'
  }
}

// Outputs for reference and further configuration
output resourceBaseName string = resourceBaseName
output location string = location

// Identity outputs
output identityName string = identityName
output identityId string = botIdentity.outputs.identityId
output identityClientId string = botIdentity.outputs.identityClientId
output identityPrincipalId string = botIdentity.outputs.identityPrincipalId

// App Service outputs
output webAppName string = appService.outputs.webAppName
output webAppId string = appService.outputs.webAppId
output webAppHostName string = appService.outputs.webAppHostName
output webAppUrl string = 'https://${appService.outputs.webAppHostName}'
output appServicePlanId string = appService.outputs.appServicePlanId

// Bot Service outputs
output BOT_ID string = botIdentity.outputs.identityClientId
output botServiceName string = botServiceName
output botEndpoint string = 'https://${appService.outputs.webAppHostName}/api/messages'

// App Registration outputs
output AAD_APP_CLIENT_ID string = appRegistration.outputs.aadAppId
output AAD_APP_ID_URI string = appRegistration.outputs.aadAppIdUri
output federatedCredentialName string = appRegistration.outputs.fciName
// Note: fciSubject is used internally for OAuth connection but not exposed as output


