# Azure Local Deployment - Simplified Approach

## Overview
This simplified Bicep deployment is designed for **local development** of Microsoft 365 Agents. It takes the Bot ID created by the Microsoft 365 Agents Toolkit and provisions the necessary Azure infrastructure using **Federated Credentials** (no client secrets required).

## Architecture

```
Input Parameters (from M365 Agents Toolkit):
  - Bot Name
  - Bot ID (Microsoft App ID)
  - Bot Endpoint (Dev Tunnel URL)
  - Tenant ID

        ↓

[STEP 1] Create SSO App Registration
         - With Federated Credentials
         - Configured for user authentication
         - Permissions: User.Read, email, openid, profile

        ↓

[STEP 2] Create Azure Bot Service
         - Single Tenant mode
         - Uses provided Bot ID as identity
         - Messaging endpoint: Dev Tunnel URL

        ↓

[STEP 3] Create OAuth Connection
         - Connects Bot to SSO App
         - Uses Federated Credentials
         - No client secret needed
```

## Key Features

### ✅ Simplified Input
- **Bot Name**: Display name for your bot
- **Bot ID**: The Microsoft App ID created by M365 Agents Toolkit
- **Bot Endpoint**: Your dev tunnel URL (e.g., `https://abc123.devtunnels.ms:5000/api/messages`)
- **Tenant ID**: Your Azure AD tenant ID

### ✅ Federated Credentials
- **No client secrets** to manage for SSO
- More secure for local development
- Credentials federated to the bot identity

### ✅ Single Tenant
- Bot configured for single-tenant mode
- Appropriate for enterprise apps
- Better security boundary

### ✅ All Resources Tagged with `-local`
- Easy to identify local development resources
- e.g., `MyBot-local`, `MyBot-sso-local`

## Deployment Steps

### 1. Prerequisites
- Azure CLI installed and logged in
- Microsoft 365 Agents Toolkit project set up
- Bot ID created by toolkit (check `.env.local` file)
- Dev tunnel running

### 2. Set Environment Variables
Update your `M365Agent/env/.env.local` file:
```bash
BOT_NAME=AzureAgentToM365ATK
BOT_ID=<your-bot-id-from-toolkit>
BOT_ENDPOINT=https://<your-tunnel>.devtunnels.ms:5000
TENANT_ID=<your-tenant-id>
```

### 3. Deploy via Azure CLI
```bash
cd M365Agent/infra

# Create resource group (if not exists)
az group create --name rg-m365agent-local --location eastus

# Deploy the Bicep template
az deployment group create \
  --resource-group rg-m365agent-local \
  --template-file azure-local.bicep \
  --parameters azure-local.parameters.json
```

### 4. Capture Outputs
The deployment will output:
- `botServiceName`: Name of the created bot service
- `ssoAppId`: SSO App Registration ID (needed for Teams manifest)
- `ssoAppIdUri`: SSO App ID URI (needed for Teams manifest)
- `oauthConnectionName`: Name of the OAuth connection (`SsoConnection`)

## What This Replaces

### ❌ Old Approach
- Multiple manual steps
- Client secret creation and rotation
- Complex credential management
- Separate bot and SSO app registrations to manage

### ✅ New Approach
- Single Bicep deployment
- Federated credentials (no secrets)
- Streamlined local development
- Automated OAuth connection setup

## Integration with M365 Agents Toolkit

After deployment, update your Teams app manifest with:
```json
{
  "bots": [{
    "botId": "<BOT_ID>"
  }],
  "webApplicationInfo": {
    "id": "<SSO_APP_ID>",
    "resource": "<SSO_APP_ID_URI>"
  }
}
```

## Outputs Reference

| Output | Description | Usage |
|--------|-------------|-------|
| `botServiceName` | Azure Bot Service name | Reference for Azure portal |
| `botId` | Bot Microsoft App ID | Already in your .env file |
| `botEndpoint` | Bot messaging endpoint | Dev tunnel URL |
| `ssoAppId` | SSO App Registration ID | Teams manifest |
| `ssoAppIdUri` | SSO App ID URI | Teams manifest |
| `oauthConnectionName` | OAuth connection name | Bot code configuration |

## Benefits

1. **Faster Setup**: One command deployment instead of multiple manual steps
2. **More Secure**: Federated credentials instead of client secrets
3. **Easier Maintenance**: All resources clearly tagged as `-local`
4. **Better Integration**: Works seamlessly with M365 Agents Toolkit
5. **Repeatable**: Can destroy and recreate easily for testing

## Cleanup

To remove all local development resources:
```bash
az group delete --name rg-m365agent-local --yes
```

## Notes

- This is designed for **local development only**
- For production deployments, use the main `azure.bicep` file with managed identities
- The `-local` suffix helps distinguish development resources
- Dev tunnel URLs change when you restart the tunnel - update the bot endpoint accordingly
