# M365 Agent Infrastructure Deployment Guide

## Overview

This guide explains the complete Azure infrastructure deployment for the M365 Agent, orchestrated by `azure.bicep`. The deployment creates a secure, production-ready bot infrastructure with Single Sign-On (SSO) capabilities for Microsoft Teams.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Azure Subscription                          │
│                                                                 │
│  Step 1: Managed Identity                                      │
│  ┌──────────────────────────┐                                 │
│  │ User Assigned Identity   │                                 │
│  │ - Identity for Bot       │                                 │
│  └────────────┬─────────────┘                                 │
│               │                                                │
│  Step 2: App Service        ↓                                 │
│  ┌──────────────────────────────────┐                         │
│  │ App Service Plan (Linux)         │                         │
│  │ ┌──────────────────────────────┐ │                         │
│  │ │ Web App (.NET 9)             │ │                         │
│  │ │ - Uses Managed Identity      │ │                         │
│  │ │ - Health Check Endpoint      │ │                         │
│  │ │ - HTTPS Only                 │ │                         │
│  │ └──────────────────────────────┘ │                         │
│  └──────────────┬───────────────────┘                         │
│                 │                                              │
│  Step 3: Azure Bot ↓                                          │
│  ┌──────────────────────────────────┐                         │
│  │ Bot Service                      │                         │
│  │ - Teams Channel                  │                         │
│  │ - Uses Managed Identity          │                         │
│  │ - Messaging Endpoint             │                         │
│  └──────────────┬───────────────────┘                         │
│                 │                                              │
│  Step 4: App Registration ↓                                   │
│  ┌──────────────────────────────────┐                         │
│  │ Entra ID Application             │                         │
│  │ - OAuth Scopes (access_as_user)  │                         │
│  │ - Federated Credentials          │                         │
│  │ - Pre-authorized Clients         │                         │
│  └──────────────┬───────────────────┘                         │
│                 │                                              │
│  Step 5: OAuth Connection ↓                                   │
│  ┌──────────────────────────────────┐                         │
│  │ Bot OAuth Connection             │                         │
│  │ - AAD v2 with Federated Creds    │                         │
│  │ - SSO Token Exchange             │                         │
│  │ - No Client Secret Required      │                         │
│  └──────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Deployment Steps Explained

### Step 1: User Assigned Managed Identity

**Module**: `modules/bot-managedidentity.bicep`

**Purpose**: Creates a managed identity that the bot uses to authenticate to Azure services securely without storing credentials.

**What Gets Created**:
- User Assigned Managed Identity resource

**Key Outputs**:
- `identityId`: Full resource ID of the identity
- `identityClientId`: Client ID (used as Bot ID)
- `identityPrincipalId`: Principal ID for RBAC assignments

**Why It Matters**:
- Eliminates need for storing passwords or secrets
- Provides secure authentication to Azure resources
- Used as the bot's identity in Bot Framework

**Configuration**:
```bicep
Resource Name: {resourceBaseName}-identity
Location: Same as resource group
```

---

### Step 2: App Service Deployment

**Module**: `modules/appservice.bicep`

**Purpose**: Creates the compute infrastructure to host your .NET 9 bot application.

**What Gets Created**:
1. **App Service Plan** (Linux)
   - Compute resources for your application
   - Configurable SKU (B1, S1, P1v2, etc.)

2. **Web App**
   - .NET 9 runtime environment
   - Configured with managed identity
   - HTTPS enforcement
   - Health check monitoring
   - CORS configured for Azure Portal

**Key Configuration**:
```bicep
Runtime: DOTNETCORE|9.0
Always On: true
HTTPS Only: true
Health Check: /health
Identity: User Assigned Managed Identity from Step 1
```

**Environment Variables Set**:
- `ASPNETCORE_ENVIRONMENT`: Production
- `WEBSITE_RUN_FROM_PACKAGE`: 1
- `AZURE_CLIENT_ID`: Managed identity client ID
- Optional: Application Insights settings

**Key Outputs**:
- `webAppName`: Name of the web app
- `webAppHostName`: Public hostname (e.g., myagent.azurewebsites.net)
- `webAppPrincipalId`: Principal ID for permissions

**Why It Matters**:
- Provides scalable hosting for your bot
- Supports continuous deployment
- Integrated monitoring and logging
- Production-grade security features

---

### Step 3: Azure Bot Service

**Module**: `modules/azurebot.bicep`

**Purpose**: Registers your web service as a bot with the Bot Framework and enables Teams channel.

**What Gets Created**:
1. **Bot Service Resource**
   - Bot Framework registration
   - Messaging endpoint configuration
   - Managed identity integration

2. **Teams Channel**
   - Enables bot in Microsoft Teams
   - Automatically configured

**Key Configuration**:
```bicep
Bot Type: azurebot
MSA App Type: UserAssignedMSI
Messaging Endpoint: https://{webAppHostName}/api/messages
Bot ID: Managed Identity Client ID
SKU: F0 (Free) or S1 (Standard)
```

**Important Properties**:
- `msaAppId`: Uses managed identity client ID
- `msaAppMSIResourceId`: References managed identity resource
- `msaAppTenantId`: Your Azure AD tenant
- `msaAppType`: UserAssignedMSI (key for managed identity)

**Key Outputs**:
- Bot service is registered and accessible via Teams
- Teams channel automatically connected

**Why It Matters**:
- Makes your bot discoverable in Teams
- Handles Bot Framework authentication
- Manages channel-specific adaptations

---

### Step 4: Entra ID App Registration

**Module**: `modules/app-registration.bicep`

**Purpose**: Creates an Azure AD application for user authentication and SSO in Teams.

**What Gets Created**:
1. **Application Registration**
   - Single-tenant application
   - OAuth 2.0 configuration
   - API permissions

2. **Custom OAuth Scope** (`access_as_user`)
   - Used for SSO authentication
   - Pre-authorized for Teams clients

3. **Federated Identity Credential**
   - Enables passwordless authentication
   - Uses subject identifier for token exchange

4. **Service Principal**
   - Enterprise application instance
   - Used for authorization

**Key Configuration**:
```bicep
Sign-in Audience: AzureADMyOrg (Single tenant)
Identifier URI: api://botid-{managedIdentityClientId}
OAuth Scope: access_as_user
Token Version: 2.0
Redirect URI: https://token.botframework.com/.auth/web/redirect
```

**Pre-authorized Applications** (No consent required):
- Teams Web Client: `1fec8e78-bce4-4aaf-ab1b-5451cc387264`
- Teams Desktop Client: `5e3ce6c0-2b1f-4285-8d4b-75ee78787346`
- Microsoft 365 Web: `4765445b-32c6-49b0-83e6-1d93765276ca`
- Microsoft 365 Desktop: `0ec893e0-5785-4de6-99da-4ed124e5296c`
- Microsoft 365 Mobile/Outlook Desktop: `d3590ed6-52b3-4102-aeff-aad2292ab01c`
- Outlook Web: `bc59ab01-8403-45c6-8796-ac3ef710b3e3`
- Outlook Mobile: `27922004-5251-4030-b22d-91ecd9a37ea4`

**Required API Permissions**:
- Microsoft Graph:
  - `openid` (Sign in and read user profile)
  - `profile` (View users' basic profile)
  - `email` (View users' email address)
  - `offline_access` (Maintain access to data)
  
- Azure Machine Learning Services:
  - `user_impersonation` (Required for Azure AI Foundry agent SSO)

**Federated Credential Configuration**:
```bicep
Issuer: https://login.microsoftonline.com/{tenantId}/v2.0
Audience: api://AzureADTokenExchange
Subject: /eid1/c/pub/t/{encodedTenantId}/a/{hardcodedEncodedAppId}/{uniqueId}
```

**Important**: The middle section of the subject (`encodedAppId`) is hardcoded to `9ExAW52n_ky4ZiS_jhpJIQ`, which is the Base64URL-encoded client ID of the **Azure Bot Service** (owned by Microsoft). This is a fixed value that represents the Microsoft service principal that performs token exchange using the federated credential. This value never changes across deployments as it identifies Microsoft's Bot Service infrastructure.

**GUID Encoding Process**:
The module uses `guid-encoder.bicep` to convert GUIDs to Base64URL format:
1. Tenant ID → Base64URL encoded
2. Azure Bot Service Client ID → Hardcoded (`9ExAW52n_ky4ZiS_jhpJIQ` - Microsoft's Bot Service)
3. Constructs federated credential subject with unique identifier

**Note**: The middle section of the FCI subject is always `9ExAW52n_ky4ZiS_jhpJIQ` - this is Microsoft's Azure Bot Service client ID that performs the token exchange. This value is fixed and constant across all deployments because it identifies the Microsoft service principal authorized to exchange tokens using your federated credential.

**Key Outputs**:
- `aadAppId`: Application (client) ID
- `aadAppIdUri`: API identifier (api://botid-{guid})
- `servicePrincipalId`: Service principal object ID
- `fciName`: Federated credential resource name

**Internal Values** (not exposed as outputs):
- `fciSubject`: Federated credential subject (constructed on-the-fly and used for OAuth connection)

**Why It Matters**:
- Enables user authentication in Teams
- Provides SSO without password prompts
- Secures API access with OAuth 2.0
- No client secrets needed (federated credentials)

---

### Step 5: OAuth Connection Configuration

**Module**: `modules/bot-oauth-connection.bicep`

**Purpose**: Configures the OAuth connection on the Bot Service to enable SSO with Azure AD using federated credentials.

**What Gets Created**:
- Bot OAuth Connection Setting with AAD v2 Federated Credentials

**Key Configuration**:
```bicep
Service Provider: AAD v2 with Federated Credentials
Service Provider ID: c00b44ab-5e16-c44c-af26-2fd5bc55eb18
Connection Name: SsoConnection
```

**Required Parameters**:
- **ClientId**: App registration client ID from Step 4
- **UniqueIdentifier**: Federated credential subject from Step 4
- **TokenExchangeUrl**: App ID URI (api://botid-{guid})
- **TenantId**: Your Azure AD tenant ID

**OAuth Scopes**:
```
{appIdUri}/.default
```
This includes all pre-authorized scopes, specifically the `access_as_user` scope.

**Authentication Flow**:
1. User interacts with bot in Teams
2. Bot requests authentication
3. Teams exchanges user token using federated credential
4. Bot receives access token with `access_as_user` scope
5. Bot can now act on behalf of the user

**Key Outputs**:
- `connectionName`: Full connection name (bot/connection)
- `connectionId`: Resource ID
- `settingId`: Bot Service setting ID
- `provisioningState`: Deployment status

**Why It Matters**:
- Enables seamless SSO in Teams
- No client secrets stored
- Secure token exchange mechanism
- Users never see login prompts (when properly configured)

---

## Deployment Dependencies

The deployment follows a strict dependency chain:

```
1. Managed Identity
   ↓
2. App Service (needs identity ID)
   ↓
3. Azure Bot (needs app service hostname and identity)
   ↓
4. App Registration (needs bot/identity client ID)
   ↓
5. OAuth Connection (needs app registration outputs)
```

**Implicit Dependencies** (handled automatically by Bicep):
- Step 2 depends on Step 1 (uses `botIdentity.outputs.identityId`)
- Step 3 depends on Step 2 (uses `appService.outputs.webAppHostName`)
- Step 5 depends on Step 4 (uses `appRegistration.outputs.*`)

---

## Required Parameters

### Mandatory Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `resourceBaseName` | string (4-20 chars) | Base name for all resources | `m365agent` |
| `botDisplayName` | string (max 42 chars) | Display name for the bot | `M365 Agent` |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `location` | string | Resource group location | Azure region |
| `webAppSKU` | string | `B1` | App Service SKU (F1, B1, S1, P1v2, etc.) |
| `botServiceSku` | string | `F0` | Bot Service SKU (F0=Free, S1=Standard) |
| `tenantId` | string | Current tenant | Azure AD tenant ID |
| `enableAppInsights` | bool | `false` | Enable Application Insights |
| `appInsightsInstrumentationKey` | string | `''` | App Insights key (if enabled) |
| `appInsightsConnectionString` | string | `''` | App Insights connection string |
| `additionalAppSettings` | array | `[]` | Additional web app settings |

---

## Deployment Commands

### Basic Deployment

```powershell
# Deploy with minimal parameters
az deployment group create `
  --resource-group "rg-m365agent-dev" `
  --template-file M365Agent/infra/azure.bicep `
  --parameters resourceBaseName="m365agent" `
               botDisplayName="M365 Agent"
```

### Production Deployment

```powershell
# Deploy with production settings
az deployment group create `
  --resource-group "rg-m365agent-prod" `
  --template-file M365Agent/infra/azure.bicep `
  --parameters resourceBaseName="m365agentprod" `
               botDisplayName="M365 Production Agent" `
               webAppSKU="P1v2" `
               botServiceSku="S1" `
               enableAppInsights=true
```

### What-If Analysis

```powershell
# Preview changes before deployment
az deployment group what-if `
  --resource-group "rg-m365agent-dev" `
  --template-file M365Agent/infra/azure.bicep `
  --parameters resourceBaseName="m365agent" `
               botDisplayName="M365 Agent"
```

### Validate Template

```powershell
# Validate Bicep syntax and dependencies
az bicep build --file M365Agent/infra/azure.bicep

# Validate deployment
az deployment group validate `
  --resource-group "rg-m365agent-dev" `
  --template-file M365Agent/infra/azure.bicep `
  --parameters resourceBaseName="m365agent"
```

---

## Output Values

After successful deployment, the following outputs are available:

### Identity Information
```
identityName: m365agent-identity
identityId: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ManagedIdentity/...
identityClientId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
identityPrincipalId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### App Service Information
```
webAppName: m365agent-app
webAppId: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Web/sites/...
webAppHostName: m365agent-app.azurewebsites.net
webAppUrl: https://m365agent-app.azurewebsites.net
```

### Bot Service Information
```
botServiceName: m365agent-bot
botEndpoint: https://m365agent-app.azurewebsites.net/api/messages
```

### App Registration Information
```
aadAppId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
aadAppIdUri: api://botid-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
servicePrincipalId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
federatedCredentialName: {appName}/BotServiceOauthConnection
```

### OAuth Connection Information
```
oauthConnectionName: m365agent-bot/SsoConnection
oauthConnectionId: /subscriptions/{sub}/resourceGroups/{rg}/providers/...
oauthSettingId: xxxxxxxxx
```

### Deployment Summary (Structured Object)
```json
{
  "resourceBaseName": "m365agent",
  "botDisplayName": "M365 Agent",
  "webAppUrl": "https://m365agent-app.azurewebsites.net",
  "botEndpoint": "https://m365agent-app.azurewebsites.net/api/messages",
  "aadAppId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "identityClientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "teamsManifestUpdates": {
    "botId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "webApplicationInfoId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "webApplicationInfoResource": "api://botid-xxxxxxxx"
  }
}
```

---

## Post-Deployment Steps

### 1. Deploy Bot Application Code

```powershell
# Build and publish your .NET 9 application
dotnet publish -c Release

# Deploy to App Service
az webapp deployment source config-zip `
  --resource-group "rg-m365agent-dev" `
  --name "m365agent-app" `
  --src "./publish.zip"
```

### 2. Update Teams App Manifest

Update your `appPackage/manifest.json` with deployment outputs:

```json
{
  "bots": [
    {
      "botId": "{identityClientId from outputs}",
      "scopes": ["personal", "team", "groupchat"]
    }
  ],
  "webApplicationInfo": {
    "id": "{aadAppId from outputs}",
    "resource": "{aadAppIdUri from outputs}"
  }
}
```

### 3. Configure Bot Code

Update your bot configuration to use the OAuth connection:

```csharp
// appsettings.json or Azure App Configuration
{
  "ConnectionName": "SsoConnection",
  "MicrosoftAppId": "{identityClientId}",
  "MicrosoftAppType": "UserAssignedMSI",
  "MicrosoftAppTenantId": "{tenantId}"
}
```

### 4. Test OAuth Connection

1. Navigate to Azure Portal → Bot Service
2. Go to **Configuration** → **OAuth Connection Settings**
3. Click on **SsoConnection**
4. Click **Test Connection**
5. Sign in and verify authentication succeeds

### 5. Grant API Permissions (If Required)

If your app needs additional Microsoft Graph permissions:

```powershell
# Grant admin consent for API permissions
az ad app permission admin-consent `
  --id {aadAppId}
```

### 6. Deploy Teams App

```powershell
# Using Teams Toolkit or manual upload
# 1. Zip the appPackage folder
# 2. Upload to Teams Admin Center or
# 3. Sideload for testing
```

---

## Resource Naming Convention

All resources follow a consistent naming pattern:

| Resource Type | Naming Pattern | Example |
|--------------|----------------|---------|
| Managed Identity | `{baseName}-identity` | `m365agent-identity` |
| App Service Plan | `{baseName}-plan` | `m365agent-plan` |
| Web App | `{baseName}-app` | `m365agent-app` |
| Bot Service | `{baseName}-bot` | `m365agent-bot` |
| App Registration | `{baseName}-app-registration` | `m365agent-app-registration` |
| OAuth Connection | `SsoConnection` | `SsoConnection` |

---

## Security Features

### 1. Managed Identity (Passwordless)
- ✅ No credentials stored in code
- ✅ Automatic token rotation
- ✅ RBAC-based access control

### 2. Federated Credentials (No Client Secrets)
- ✅ Certificate-less authentication
- ✅ Token exchange via trusted issuer
- ✅ No secret rotation required

### 3. HTTPS Enforcement
- ✅ TLS 1.2 minimum
- ✅ HTTPS-only web app
- ✅ Secure messaging endpoint

### 4. Application Security
- ✅ CORS restricted to Azure Portal
- ✅ FTPS only for file access
- ✅ Health check monitoring

### 5. OAuth 2.0 / OpenID Connect
- ✅ Industry-standard authentication
- ✅ Scoped permissions
- ✅ Pre-authorized clients (no consent prompt)

---

## Troubleshooting

### Deployment Fails at Step 1 (Identity)

**Error**: "Authorization failed"
**Solution**: Ensure you have `Microsoft.ManagedIdentity/userAssignedIdentities/write` permission

### Deployment Fails at Step 4 (App Registration)

**Error**: "Insufficient privileges"
**Solution**: You need **Application Administrator** or **Cloud Application Administrator** role

**Error**: "GUID encoding fails"
**Solution**: Check that deployment scripts are enabled in your subscription

### Deployment Fails at Step 5 (OAuth Connection)

**Error**: "Mismatch between Service Provider Id and Name"
**Solution**: Verify service provider ID is correct: `c00b44ab-5e16-c44c-af26-2fd5bc55eb18`

**Error**: "Invalid parameter"
**Solution**: Ensure all parameter keys use correct casing (`ClientId`, `UniqueIdentifier`, etc.)

### OAuth Connection Test Fails

**Problem**: "Test Connection" fails in Azure Portal

**Check**:
1. Federated credential is created correctly
2. App ID URI matches: `api://botid-{clientId}`
3. Scopes are configured: `{appIdUri}/.default`
4. Tenant ID is correct

### SSO Doesn't Work in Teams

**Check**:
1. Teams manifest has correct `botId` (managed identity client ID)
2. `webApplicationInfo` section is populated correctly
3. App registration has all pre-authorized clients
4. OAuth connection name matches bot code (`SsoConnection`)

---

## Cost Estimation

### Development/Testing Environment
- App Service Plan (B1): ~$13/month
- Bot Service (F0): Free (10,000 messages/month)
- Managed Identity: Free
- App Registration: Free
- **Total**: ~$13/month

### Production Environment
- App Service Plan (P1v2): ~$80/month
- Bot Service (S1): ~$0.50/1000 messages
- Application Insights: ~$2.30/GB
- Managed Identity: Free
- App Registration: Free
- **Total**: ~$85-100/month (depending on usage)

---

## Monitoring and Diagnostics

### Application Insights Integration

If enabled (`enableAppInsights=true`):
- Automatic request tracking
- Dependency tracking
- Exception logging
- Custom metrics support

### App Service Diagnostics

Available in Azure Portal:
- App Service logs
- HTTP logs
- Failed request tracing
- Deployment logs

### Bot Service Analytics

Available in Bot Service:
- Message volume
- Channel analytics
- Conversation metrics

---

## Updating the Deployment

### Update Infrastructure

```powershell
# Make changes to Bicep files
# Redeploy with same parameters
az deployment group create `
  --resource-group "rg-m365agent-dev" `
  --template-file M365Agent/infra/azure.bicep `
  --parameters resourceBaseName="m365agent" `
               botDisplayName="M365 Agent"
```

Bicep will detect changes and update only modified resources.

### Update Application Code

```powershell
# Continuous deployment recommended
az webapp deployment source config-zip `
  --resource-group "rg-m365agent-dev" `
  --name "m365agent-app" `
  --src "./publish.zip"
```

---

## Clean Up Resources

### Delete Resource Group

```powershell
# Delete all resources at once
az group delete --name "rg-m365agent-dev" --yes
```

### Note on App Registration

App registrations are tenant-level resources and may need manual cleanup:

```powershell
# List app registrations
az ad app list --filter "startswith(displayName,'m365agent')"

# Delete app registration
az ad app delete --id {appId}
```

---

## Best Practices

### 1. Use Separate Environments
- Development: `rg-m365agent-dev`
- Staging: `rg-m365agent-stage`
- Production: `rg-m365agent-prod`

### 2. Tag Resources
Add tags to resource group for cost tracking and organization:
```powershell
az group update --name "rg-m365agent-dev" --tags Environment=Development Project=M365Agent
```

### 3. Enable Diagnostic Logs
Configure diagnostic settings for production monitoring

### 4. Use Azure Key Vault
For any additional secrets (if needed), use Azure Key Vault with managed identity

### 5. Implement CI/CD
- Use GitHub Actions or Azure DevOps
- Automate Bicep deployments
- Automate application deployments

### 6. Monitor Costs
Set up cost alerts in Azure Cost Management

---

## Additional Resources

### Documentation
- [Azure Bot Service Documentation](https://docs.microsoft.com/azure/bot-service/)
- [Teams Bot Development](https://docs.microsoft.com/microsoftteams/platform/bots/)
- [Managed Identities](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Federated Identity Credentials](https://docs.microsoft.com/azure/bot-service/bot-builder-authentication-federated-credential)

### Related Files
- `modules/bot-managedidentity.bicep` - Managed identity module
- `modules/appservice.bicep` - App Service module
- `modules/azurebot.bicep` - Bot Service module
- `modules/app-registration.bicep` - App registration module
- `modules/bot-oauth-connection.bicep` - OAuth connection module
- `modules/guid-encoder.bicep` - GUID encoding utility
- `GUID_ENCODER_GUIDE.md` - GUID encoding details
- `BOT_OAUTH_CONNECTION.md` - OAuth connection details

---

## Support

For issues or questions:
1. Check Azure deployment logs
2. Review Bot Service diagnostics
3. Verify all outputs are correct
4. Test OAuth connection in Azure Portal
5. Check Teams app manifest configuration

---

**Last Updated**: October 2025
**Bicep Version**: Latest
**Azure CLI Version**: 2.52.0+
