// Local Development Bicep file for M365 Agent
// Simplified approach: Uses Bot ID (created by M365 Agents Toolkit) for both Bot Service and SSO
// This deploys: Service Principal → Azure Bot Service → OAuth Connections
// Note: App Registration is managed by M365 Agents Toolkit, not this Bicep template

targetScope = 'resourceGroup'

@description('Name of the bot (used for display and resource naming)')
param botName string

@description('The Bot ID (Microsoft App ID) - provided by M365 Agents Toolkit')
param botId string

@description('The Bot Object ID - provided by M365 Agents Toolkit')
param botObjectId string

@description('Bot messaging endpoint (dev tunnel URL)')
param botEndpoint string

@description('Tenant ID for single-tenant bot configuration')
param tenantId string

@description('Location for all resources')
param location string = resourceGroup().location

@description('The SKU for the Bot Service (F0 for local development)')
param botServiceSku string = 'F0'

@description('SSO App ID - use 00000000-0000-0000-0000-000000000000 for first-time deployment')
param ssoAppId string = '00000000-0000-0000-0000-000000000000'

// Variables
var botServiceName = '${botName}-local'
var nullGuid = '00000000-0000-0000-0000-000000000000'
var isFirstTimeDeployment = ssoAppId == nullGuid

// Use Bot ID for SSO (single app approach)
var ssoAppIdValue = botId
var ssoAppIdUriValue = 'api://botid-${botId}'

// ========================================
// STEP 0: Create Service Principal for Bot ID
// ========================================
module botServicePrincipal 'modules/service-principal.bicep' = {
  name: 'deploy-bot-service-principal-local'
  params: {
    appId: botId
  }
}

// ========================================
// STEP 1: Add Federated Credentials to Bot App (First-time only)
// ========================================
module botFederatedCredentials 'modules/bot-managedidentity.bicep' = if (isFirstTimeDeployment) {
  name: 'deploy-bot-federated-credentials-local'
  params: {
    botId: botId
    botObjectId: botObjectId
    tenantId: tenantId
    location: location
  }
}

// ========================================
// STEP 2: Create Azure Bot Service
// ========================================
resource botService 'Microsoft.BotService/botServices@2021-03-01' = {
  kind: 'azurebot'
  location: 'global'
  name: botServiceName
  properties: {
    displayName: botName
    endpoint: botEndpoint
    msaAppId: botId
    msaAppTenantId: tenantId
    msaAppType: 'SingleTenant'
  }
  sku: {
    name: botServiceSku
  }
  dependsOn: [
    botServicePrincipal
  ]
}

// Connect to Microsoft Teams
resource botServiceMsTeamsChannel 'Microsoft.BotService/botServices/channels@2021-03-01' = {
  parent: botService
  location: 'global'
  name: 'MsTeamsChannel'
  properties: {
    channelName: 'MsTeamsChannel'
  }
}

// ========================================
// STEP 3: Create OAuth Connection for SSO (First-time only)
// ========================================
module botOAuthConnection 'modules/bot-oauth-connection.bicep' = if (isFirstTimeDeployment) {
  name: 'deploy-bot-oauth-connection-sso-local'
  params: {
    botServiceName: botServiceName
    connectionName: 'SsoConnection'
    aadAppId: ssoAppIdValue
    aadAppIdUri: ssoAppIdUriValue
    federatedCredentialSubject: botFederatedCredentials.outputs.fciSubject
    scopes: '${ssoAppIdUriValue}/access_as_user'
    tenantId: tenantId
    location: 'global'
  }
  dependsOn: [
    botService
    botFederatedCredentials
  ]
}

// ========================================
// STEP 4: Create OAuth Connection for AI Foundry (First-time only)
// ========================================
module botOAuthConnectionAIFoundry 'modules/bot-oauth-connection.bicep' = if (isFirstTimeDeployment) {
  name: 'deploy-bot-oauth-connection-aifoundry-local'
  params: {
    botServiceName: botServiceName
    connectionName: 'aifoundryaccess'
    aadAppId: ssoAppIdValue
    aadAppIdUri: ssoAppIdUriValue
    federatedCredentialSubject: botFederatedCredentials.outputs.fciSubject
    scopes: 'https://ai.azure.com/user_impersonation'
    tenantId: tenantId
    location: 'global'
  }
  dependsOn: [
    botService
    botFederatedCredentials
  ]
}

// ========================================
// OUTPUTS
// ========================================
output botServiceName string = botService.name
output botServiceId string = botService.id
output botEndpoint string = botEndpoint
output bot_Id string = botId
output tenantId string = tenantId
output botServicePrincipalId string = botServicePrincipal.outputs.servicePrincipalId

// SSO uses the same app as Bot
output sso_App_Id string = ssoAppIdValue
output sso_App_Id_Uri string = ssoAppIdUriValue
output ssoFederatedCredentialName string = isFirstTimeDeployment ? botFederatedCredentials.outputs.fciName : ''
output ssoFederatedCredentialSubject string = isFirstTimeDeployment ? botFederatedCredentials.outputs.fciSubject : ''

// OAuth Connection names
output oauth_Connection_Name string = 'SsoConnection'
output AIFoundry_Connection_Name string = 'aifoundryaccess'

// Summary
output localDevSummary object = {
  botName: botName
  botServiceName: botService.name
  botEndpoint: botEndpoint
  botId: botId
  tenantId: tenantId
  botServicePrincipalId: botServicePrincipal.outputs.servicePrincipalId
  ssoAppId: ssoAppIdValue
  ssoAppIdUri: ssoAppIdUriValue
  oauthConnectionName: 'SsoConnection'
  deploymentMode: isFirstTimeDeployment ? 'First-time (created all resources)' : 'Update (bot endpoint only)'
}
