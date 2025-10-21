// Local Development orchestration file for M365 Agent
// This deploys: Bot App Registration (with secret) → Azure Bot → SSO App Registration → OAuth Connection
// Designed for local development without managed identity

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

@description('The SKU for the Bot Service')
@allowed([
  'F0'
  'S1'
])
param botServiceSku string = 'F0'

@description('Tenant ID for the Entra ID applications')
param tenantId string = tenant().tenantId

@description('Local development bot messaging endpoint (e.g., https://yourtunnel.ngrok.io/api/messages)')
param localBotEndpoint string

// Generate resource names
var botServiceName = '${resourceBaseName}-bot-local'
var botAppRegName = '${resourceBaseName}-bot-local'
var ssoAppRegName = '${resourceBaseName}-sso-local'

// Step 1: Create Bot App Registration with Client Secret
// This is used for local development authentication
// Note: Client secret must be created manually in Azure Portal after deployment
module botAppRegistration 'modules/bot-app-registration.bicep' = {
  name: 'deploy-bot-app-registration'
  params: {
    appName: botAppRegName
    tenantId: tenantId
  }
}

// Step 2: Create Azure Bot Service using the bot app registration
module azureBot 'modules/azurebot-local.bicep' = {
  name: 'deploy-azure-bot-local'
  params: {
    resourceBaseName: resourceBaseName
    botDisplayName: botDisplayName
    botServiceName: botServiceName
    botServiceSku: botServiceSku
    botAppId: botAppRegistration.outputs.appId
    botAppTenantId: tenantId
    botEndpoint: localBotEndpoint
  }
}

// Step 3: Create SSO App Registration with Federated Credentials
module ssoAppRegistration 'modules/app-registration.bicep' = {
  name: 'deploy-sso-app-registration'
  params: {
    aadAppName: ssoAppRegName
    botId: botAppRegistration.outputs.appId
    tenantId: tenantId
    location: location
  }
  dependsOn: [
    azureBot
  ]
}

// Step 4: Configure OAuth Connection with Azure AD v2 and Federated Credentials
module botOAuthConnection 'modules/bot-oauth-connection.bicep' = {
  name: 'deploy-bot-oauth-connection'
  params: {
    botServiceName: botServiceName
    connectionName: 'SsoConnection'
    aadAppId: ssoAppRegistration.outputs.aadAppId
    aadAppIdUri: ssoAppRegistration.outputs.aadAppIdUri
    federatedCredentialSubject: ssoAppRegistration.outputs.fciSubject
    scopes: '${ssoAppRegistration.outputs.aadAppIdUri}/access_as_user'
    tenantId: tenantId
    location: 'global'
  }
}

// Outputs for local development configuration
output resourceBaseName string = resourceBaseName
output location string = location

// Bot App Registration outputs (for bot authentication)
output botAppId string = botAppRegistration.outputs.appId
output botAppObjectId string = botAppRegistration.outputs.objectId
// Note: Client secret must be created manually in Azure Portal after deployment

// Bot Service outputs
output botServiceName string = botServiceName
output botEndpoint string = localBotEndpoint

// SSO App Registration outputs (for user authentication)
output ssoAppId string = ssoAppRegistration.outputs.aadAppId
output ssoAppObjectId string = ssoAppRegistration.outputs.aadAppObjectId
output ssoAppIdUri string = ssoAppRegistration.outputs.aadAppIdUri
output ssoServicePrincipalId string = ssoAppRegistration.outputs.servicePrincipalId
output ssoFederatedCredentialName string = ssoAppRegistration.outputs.fciName

// OAuth Connection outputs
output oauthConnectionName string = botOAuthConnection.outputs.connectionName
output oauthConnectionId string = botOAuthConnection.outputs.connectionId
output oauthSettingId string = botOAuthConnection.outputs.settingId

// Local development configuration summary
output localDevSummary object = {
  resourceBaseName: resourceBaseName
  botDisplayName: botDisplayName
  botEndpoint: localBotEndpoint
  botAppId: botAppRegistration.outputs.appId
  botAppPassword: '***(CREATE MANUALLY IN PORTAL)***'
  ssoAppId: ssoAppRegistration.outputs.aadAppId
  appsettingsJson: {
    MicrosoftAppType: 'SingleTenant'
    MicrosoftAppId: botAppRegistration.outputs.appId
    MicrosoftAppPassword: '***(CREATE MANUALLY IN PORTAL)***'
    MicrosoftAppTenantId: tenantId
    ConnectionName: 'SsoConnection'
  }
  teamsManifestUpdates: {
    botId: botAppRegistration.outputs.appId
    webApplicationInfoId: ssoAppRegistration.outputs.aadAppId
    webApplicationInfoResource: ssoAppRegistration.outputs.aadAppIdUri
  }
}
