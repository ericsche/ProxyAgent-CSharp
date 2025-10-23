// Local Development Bicep file for M365 Agent
// Simplified approach: takes Bot ID and creates infrastructure with Federated Credentials
// This deploys: App Registration (with Federated Credentials) → Azure Bot (Single Tenant) → OAuth Connection

targetScope = 'resourceGroup'

@description('Name of the bot (used for display and resource naming)')
param botName string

@description('The Bot ID (Microsoft App ID) - provided by Microsoft 365 Agents Toolkit')
param botId string

@description('Bot messaging endpoint (dev tunnel URL, e.g., https://abc123.devtunnels.ms:5000/api/messages)')
param botEndpoint string

@description('Tenant ID for single-tenant bot configuration')
param tenantId string

@description('Location for all resources')
param location string = resourceGroup().location

@description('The SKU for the Bot Service (F0 for local development)')
param botServiceSku string = 'F0'

@description('SSO App ID - use 00000000-0000-0000-0000-000000000000 for first-time deployment, provide actual GUID to skip SSO/OAuth creation')
param ssoAppId string = '00000000-0000-0000-0000-000000000000'

// Generate resource names with -local suffix for clarity
var botServiceName = '${botName}-local'
var ssoAppName = '${botName}-sso-local'

// Determine if this is a first-time deployment (using null GUID as indicator)
var nullGuid = '00000000-0000-0000-0000-000000000000'
var isFirstTimeDeployment = ssoAppId == nullGuid

// ========================================
// STEP 0: Create Service Principal for Bot ID
// ========================================
// The M365 Agents Toolkit creates an App Registration but not the Service Principal
// This is required for the Bot Service and to issue tokens
module botServicePrincipal 'modules/service-principal.bicep' = {
  name: 'deploy-bot-service-principal-local'
  params: {
    appId: botId
    displayName: '${botName}-bot-local'
  }
}

// ========================================
// STEP 1: Create SSO App Registration with Federated Credentials (First-time only)
// ========================================
// Only deployed when ssoAppId parameter is empty (first-time deployment)
module ssoAppRegistration 'modules/app-registration.bicep' = if (isFirstTimeDeployment) {
  name: 'deploy-sso-app-registration-local'
  params: {
    aadAppName:   ssoAppName
    botId: botId
    tenantId: tenantId
    location: location
  }
}

// ========================================
// STEP 2: Create or Update Azure Bot Service (Single Tenant)
// ========================================
// This will create the bot if it doesn't exist, or update the endpoint if it does
// Bicep handles this idempotently
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

// Connect the bot service to Microsoft Teams
resource botServiceMsTeamsChannel 'Microsoft.BotService/botServices/channels@2021-03-01' = {
  parent: botService
  location: 'global'
  name: 'MsTeamsChannel'
  properties: {
    channelName: 'MsTeamsChannel'
  }
}

// ========================================
// STEP 3: Create OAuth Connection with Federated Credentials (First-time only)
// ========================================
// Only deployed when ssoAppId parameter is empty (first-time deployment)
module botOAuthConnection 'modules/bot-oauth-connection.bicep' = if (isFirstTimeDeployment) {
  name: 'deploy-bot-oauth-connection-local'
  params: {
    botServiceName: botServiceName
    connectionName: 'SsoConnection'
    aadAppId: ssoAppRegistration!.outputs.aadAppId
    aadAppIdUri: ssoAppRegistration!.outputs.aadAppIdUri
    federatedCredentialSubject: ssoAppRegistration!.outputs.fciSubject
    scopes: '${ssoAppRegistration!.outputs.aadAppIdUri}/access_as_user'
    tenantId: tenantId
    location: 'global'
  }
  dependsOn: [
    botService
  ]
}

// ========================================
// OUTPUTS
// ========================================

// Bot Service outputs
output botServiceName string = botService.name
output botServiceId string = botService.id
output botEndpoint string = botEndpoint
output botId string = botId
output tenantId string = tenantId
output botServicePrincipalId string = botServicePrincipal.outputs.servicePrincipalId

// SSO App Registration outputs (for user authentication)
// Return module outputs on first-time, else return the provided parameter
output sso_App_Id string = isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppId : ssoAppId
output ssoAppObjectId string = isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppObjectId : ''
output sso_App_Id_Uri string = isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppIdUri : ''
output ssoServicePrincipalId string = isFirstTimeDeployment ? ssoAppRegistration!.outputs.servicePrincipalId : ''
output ssoFederatedCredentialName string = isFirstTimeDeployment ? ssoAppRegistration!.outputs.fciName : ''

// OAuth Connection outputs (only available on first-time deployment)
output oauth_Connection_Name string = isFirstTimeDeployment ? botOAuthConnection!.outputs.connectionName : 'SsoConnection'
output oauthConnectionId string = isFirstTimeDeployment ? botOAuthConnection!.outputs.connectionId : ''
output oauthSettingId string = isFirstTimeDeployment ? botOAuthConnection!.outputs.settingId : ''

// Local development configuration summary
output localDevSummary object = {
  botName: botName
  botServiceName: botService.name
  botEndpoint: botEndpoint
  botId: botId
  tenantId: tenantId
  botServicePrincipalId: botServicePrincipal.outputs.servicePrincipalId
  ssoAppId: isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppId : ssoAppId
  ssoAppIdUri: isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppIdUri : ''
  oauthConnectionName: 'SsoConnection'
  deploymentMode: isFirstTimeDeployment ? 'First-time (created all resources)' : 'Update (bot endpoint only)'
}
