# Local Development Deployment Guide

## Overview

This guide explains the infrastructure deployment for local M365 Agent development using `azure-local.bicep`. This deployment is optimized for debugging with tools like ngrok, VS Code, or Visual Studio, using Single Tenant authentication with client secrets instead of managed identities.

## Key Differences from Production Deployment

| Feature | Production (`azure.bicep`) | Local Dev (`azure-local.bicep`) |
|---------|---------------------------|--------------------------------|
| **Identity** | User Assigned Managed Identity | App Registration with Client Secret |
| **Authentication** | Managed Identity (UserAssignedMSI) | Single Tenant + Client Secret |
| **App Service** | Azure App Service | Local development environment |
| **Endpoint** | Static Azure URL | Dynamic (devtunnel) |
| **SSO** | Federated Credentials | Federated Credentials |
| **Cost** | ~$13-100/month | Bot Service only (~Free with F0) |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Azure Subscription                          │
│                                                                 │
│  Step 1: Bot App Registration                                  │
│  ┌──────────────────────────┐                                 │
│  │ Entra ID Application     │                                 │
│  │ - Single Tenant          │                                 │
│  │ - Client Secret (Manual) │                                 │
│  └────────────┬─────────────┘                                 │
│               │                                                │
│  Step 2: Azure Bot ↓                                          │
│  ┌──────────────────────────────────┐                         │
│  │ Bot Service                      │                         │
│  │ - Single Tenant Auth             │                         │
│  │ - Teams Channel                  │                         │
│  │ - Dynamic Endpoint (ngrok)       │                         │
│  └──────────────┬───────────────────┘                         │
│                 │                                              │
│  Step 3: SSO App Registration ↓                               │
│  ┌──────────────────────────────────┐                         │
│  │ Entra ID Application             │                         │
│  │ - OAuth Scopes (access_as_user)  │                         │
│  │ - Federated Credentials          │                         │
│  │ - Pre-authorized Clients         │                         │
│  └──────────────┬───────────────────┘                         │
│                 │                                              │
│  Step 4: OAuth Connection ↓                                   │
│  ┌──────────────────────────────────┐                         │
│  │ Bot OAuth Connection             │                         │
│  │ - AAD v2 with Federated Creds    │                         │
│  │ - SSO Token Exchange             │                         │
│  └──────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
                       │
                       ↓
            Local Development Machine
        ┌──────────────────────────────┐
        │  .NET 9 Bot Application      │
        │  - VS Code / Visual Studio   │
        │  - Debugger Attached         │
        │  - ngrok/devtunnel           │
        └──────────────────────────────┘
```

---

## Deployment Steps

### Prerequisites

1. **Azure CLI** installed and logged in
2. **ngrok** or **devtunnels** for local endpoint exposure
3. **Application Administrator** role in Azure AD
4. **Contributor** role on Azure subscription

### Step 1: Start Local Tunnel

Before deployment, start your devtunnel to get the endpoint URL:

```powershell
# Create a persistent tunnel (first time only)
devtunnel create --allow-anonymous

# Host the tunnel on port 5000
devtunnel port create -p 5000
devtunnel host
```

Copy the HTTPS URL from the output (e.g., `https://abc123-5000.usw2.devtunnels.ms`)

### Step 2: Deploy Infrastructure

```powershell
# Deploy to Azure
az deployment group create `
  --resource-group "rg-m365agent-dev-local" `
  --template-file M365Agent/infra/azure-local.bicep `
  --parameters resourceBaseName="m365agentdev" `
               botDisplayName="M365 Agent (Local Dev)" `
               localBotEndpoint="https://abc123-5000.usw2.devtunnels.ms/api/messages"
```

### Step 3: Create Client Secret

After deployment completes:

1. Navigate to **Azure Portal** → **App Registrations**
2. Find `m365agentdev-bot-local` application
3. Go to **Certificates & secrets**
4. Click **New client secret**
5. Set description: "Local Development Secret"
6. Set expiration: 180 days (or custom)
7. Click **Add**
8. **Copy the secret value immediately** (you won't see it again!)

### Step 4: Configure Local Application

Update your `appsettings.Development.json`:

```json
{
  "MicrosoftAppType": "SingleTenant",
  "MicrosoftAppId": "{botAppId from deployment output}",
  "MicrosoftAppPassword": "{client secret from Step 3}",
  "MicrosoftAppTenantId": "{your tenant ID}",
  "ConnectionName": "SsoConnection"
}
```

---

## Deployment Components Explained

### Step 1: Bot App Registration

**Module**: `modules/bot-app-registration.bicep`

**Purpose**: Creates an Entra ID application for bot authentication (replaces managed identity).

**Configuration**:
```bicep
Sign-in Audience: AzureADMyOrg (Single tenant)
Authentication: Client ID + Client Secret
```

**Outputs**:
- `botAppId`: Application (client) ID for your bot
- `botAppObjectId`: Object ID of the application
- `servicePrincipalId`: Service principal ID

**Post-Deployment**: Client secret must be created manually in Azure Portal.

---

### Step 2: Azure Bot Service (Local)

**Module**: `modules/azurebot-local.bicep`

**Purpose**: Registers bot with Bot Framework using Single Tenant authentication.

**Key Configuration**:
```bicep
Bot Type: azurebot
MSA App Type: SingleTenant (not UserAssignedMSI)
Messaging Endpoint: {localBotEndpoint}
Bot ID: {botAppId}
SKU: F0 (Free)
```

**Important**: 
- Endpoint URL can be updated dynamically when your tunnel changes
- No managed identity - uses client ID + secret

---

### Step 3: SSO App Registration

**Module**: `modules/app-registration.bicep` (same as production)

**Purpose**: Creates Azure AD application for user authentication and SSO.

**Configuration**: Identical to production deployment
- OAuth scope: `access_as_user`
- Federated credentials for token exchange
- Pre-authorized Teams clients

**App ID URI**: `api://botid-{botAppId}`

---

### Step 4: OAuth Connection

**Module**: `modules/bot-oauth-connection.bicep` (same as production)

**Purpose**: Configures OAuth connection with federated credentials for SSO.

**Configuration**:
```bicep
Service Provider: AAD v2 with Federated Credentials
Connection Name: SsoConnection
Scopes: {appIdUri}/access_as_user
```

---

## Local Development Workflow

### 1. Start Your Bot Locally

```powershell
# Run your .NET 9 bot application
cd AzureAgentToM365ATK
dotnet run

# Or press F5 in Visual Studio/VS Code
```

Your bot should start on `http://localhost:5000`

### 2. Start Tunnel

```powershell
# In a separate terminal
devtunnel host
```

### 3. Update Bot Endpoint (if tunnel URL changed)

```powershell
# Update bot endpoint
az bot update `
  --resource-group "rg-m365agent-dev-local" `
  --name "m365agentdev-bot-local" `
  --endpoint "https://new-tunnel-url.devtunnels.ms/api/messages"
```

### 4. Test in Teams

1. Update Teams app manifest with bot IDs
2. Sideload app in Teams
3. Start conversation with bot
4. Debug breakpoints in your local IDE

---

## Updating Configuration

### Update Bot Endpoint

When your devtunnel URL changes:

```powershell
az bot update `
  --resource-group "rg-m365agent-dev-local" `
  --name "m365agentdev-bot-local" `
  --endpoint "https://new-url.devtunnels.ms/api/messages"
```

### Rotate Client Secret

When secret expires:

1. Azure Portal → App Registrations → Your bot app
2. Certificates & secrets → New client secret
3. Update `appsettings.Development.json` with new secret
4. Restart your bot application

### Test OAuth Connection

```powershell
# Test the OAuth connection
az bot authsetting test `
  --name "m365agentdev-bot-local" `
  --resource-group "rg-m365agent-dev-local" `
  --setting-name "SsoConnection"
```

---

## Deployment Outputs

After successful deployment:

```
Bot App Registration:
  botAppId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  botAppObjectId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Note: Create client secret in Azure Portal

Bot Service:
  botServiceName: m365agentdev-bot-local
  botEndpoint: https://abc123-5000.usw2.devtunnels.ms/api/messages

SSO App Registration:
  ssoAppId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  ssoAppIdUri: api://botid-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

OAuth Connection:
  oauthConnectionName: m365agentdev-bot-local/SsoConnection
  oauthSettingId: xxxxxxxxx

Configuration Summary:
  MicrosoftAppType: SingleTenant
  MicrosoftAppId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  MicrosoftAppPassword: (create manually in portal)
  MicrosoftAppTenantId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  ConnectionName: SsoConnection
```

---

## Required Parameters

### Mandatory

| Parameter | Description | Example |
|-----------|-------------|---------|
| `resourceBaseName` | Base name for resources (4-20 chars) | `m365agentdev` |
| `botDisplayName` | Display name for bot (max 42 chars) | `M365 Agent (Dev)` |
| `localBotEndpoint` | Your devtunnel URL + /api/messages | `https://abc123-5000.usw2.devtunnels.ms/api/messages` |

### Optional

| Parameter | Default | Description |
|-----------|---------|-------------|
| `location` | Resource group location | Azure region |
| `botServiceSku` | `F0` | Bot Service SKU (F0 or S1) |
| `tenantId` | Current tenant | Azure AD tenant ID |

---

## Teams App Manifest Updates

Update your `appPackage/manifest.json`:

```json
{
  "bots": [
    {
      "botId": "{botAppId from outputs}",
      "scopes": ["personal", "team", "groupchat"]
    }
  ],
  "webApplicationInfo": {
    "id": "{ssoAppId from outputs}",
    "resource": "{ssoAppIdUri from outputs}"
  }
}
```

---

## Troubleshooting

### Bot Not Receiving Messages

**Check**:
1. Tunnel is running and accessible
2. Bot endpoint URL is correct in Azure Portal
3. Bot application is running locally
4. Firewall allows inbound connections

**Test**:
```powershell
# Test your endpoint
curl https://your-tunnel.devtunnels.ms/api/messages -X POST
```

### Authentication Fails

**Check**:
1. Client secret is correct in `appsettings.json`
2. Client secret hasn't expired
3. `MicrosoftAppType` is set to `SingleTenant`
4. Tenant ID matches your Azure AD tenant

### SSO Not Working

**Check**:
1. OAuth connection test passes in portal
2. Teams manifest has correct app IDs
3. Federated credential is created
4. SSO app ID URI matches: `api://botid-{botAppId}`

### Tunnel URL Changes

**Problem**: Devtunnel URL changes or needs to be recreated

**Solutions**:
1. Use `devtunnel create` to create persistent tunnel (URL stays the same)
2. If URL changes, update bot endpoint:
   ```powershell
   az bot update --name "bot-name" --resource-group "rg" --endpoint "new-url"
   ```
3. List existing tunnels: `devtunnel list`

---

## Cost Considerations

### Local Development Infrastructure

- **Bot Service (F0)**: Free
  - 10,000 messages/month included
  - Unlimited channels
  
- **App Registrations**: Free
  - No cost for Entra ID applications

- **Total Azure Cost**: **~$0/month**

### Local Tunnel Options

| Service | Free Tier | Features |
|---------|-----------|----------|
| **devtunnels** (Recommended) | Persistent URL, free | Microsoft service, integrated with Visual Studio |
| **ngrok** | Dynamic URL (changes on restart) | Popular, requires paid plan for persistent URLs |
| **localtunnel** | Dynamic URL, open source | Community maintained |

**Recommendation**: Use Azure devtunnels - it's free, persistent, and Microsoft-supported

---

## Best Practices

### 1. Separate Environments

Use different resource base names:
- Development: `m365agent-dev`
- Testing: `m365agent-test`  
- Your local: `m365agent-yourname`

### 2. Client Secret Management

- ✅ Store in User Secrets (not in code)
- ✅ Set expiration to 180 days max
- ✅ Rotate before expiration
- ❌ Never commit to source control

### 3. Teams App Sideloading

- Use separate app manifest for development
- Different bot name to distinguish from production
- Test in your personal Team first

### 4. Debugging

- Enable detailed logging in `appsettings.Development.json`
- Use Application Insights (optional for local dev)
- Set breakpoints in bot message handlers

### 5. Tunnel Management

- Keep tunnel running during debug sessions
- Document current tunnel URL for team members
- Use persistent tunnels for stable development

---

## Transition to Production

When ready to deploy to production:

1. **Deploy production infrastructure** using `azure.bicep`
2. **Update Teams manifest** with production bot ID
3. **Submit to Teams store** or deploy organization-wide
4. **Monitor** using Application Insights
5. **Keep local dev environment** for ongoing development

**Note**: Local and production environments are completely separate - you can run both simultaneously.

---

## Clean Up

### Delete Local Development Resources

```powershell
# Delete resource group
az group delete --name "rg-m365agent-dev-local" --yes

# Delete app registrations (manual)
# Azure Portal → App Registrations → Delete each app
```

### Keep Bot for Future Development

To reuse the same bot:
1. Keep bot app registration and secret
2. Redeploy other resources as needed
3. Update bot endpoint when tunnel URL changes

---

## Additional Resources

### Tunneling Tools
- [Azure devtunnels (Recommended)](https://learn.microsoft.com/azure/developer/dev-tunnels/)
- [devtunnels CLI Reference](https://learn.microsoft.com/azure/developer/dev-tunnels/cli-commands)
- [Install devtunnels](https://learn.microsoft.com/azure/developer/dev-tunnels/get-started)

### Bot Development
- [Bot Framework SDK](https://docs.microsoft.com/azure/bot-service/bot-service-overview)
- [Teams Bot Development](https://docs.microsoft.com/microsoftteams/platform/bots/)
- [Local Debugging Guide](https://learn.microsoft.com/azure/bot-service/bot-service-debug-bot)

### Related Files
- `azure-local.bicep` - Local development orchestration
- `modules/bot-app-registration.bicep` - Bot app registration module
- `modules/azurebot-local.bicep` - Bot service for local dev
- `modules/app-registration.bicep` - SSO app registration (shared)
- `modules/bot-oauth-connection.bicep` - OAuth connection (shared)

---

**Last Updated**: October 2025
**Bicep Version**: Latest
**Azure CLI Version**: 2.52.0+
