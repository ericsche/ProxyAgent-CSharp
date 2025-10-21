# Azure Production Deployment - Quick Start

This guide walks you through deploying your M365 Agent to Azure using the Microsoft 365 Agents Toolkit.

## What Gets Deployed

When you run `atk provision`, the following Azure resources are created:

1. **User Assigned Managed Identity** - Bot identity (no passwords needed!)
2. **App Service Plan + Web App** - Hosts your .NET bot application
3. **Azure Bot Service** - Registers bot with Teams/M365
4. **Entra ID App Registration** - Enables SSO with federated credentials
5. **OAuth Connection** - Configures SSO for Teams users

## Prerequisites

### Required Tools
- ✅ **Azure CLI** - [Install](https://learn.microsoft.com/cli/azure/install-azure-cli)
- ✅ **Microsoft 365 Agents Toolkit CLI** - [Install](https://aka.ms/m365agentstoolkit-cli)
- ✅ **.NET 9 SDK** - [Install](https://dotnet.microsoft.com/download/dotnet/9.0)

### Required Permissions
- **Azure**: Contributor role on subscription or resource group
- **Entra ID**: Application Administrator or Cloud Application Administrator

### Azure Login
```powershell
az login
```

## Step-by-Step Deployment

### Step 1: Configure Environment Variables

Edit `M365Agent/env/.env.dev`:

```bash
# Update these values before provisioning
AZURE_SUBSCRIPTION_ID=your-subscription-id-here
AZURE_RESOURCE_GROUP_NAME=rg-m365agent-prod
RESOURCE_SUFFIX=prod123

# Keep these as-is
TEAMSFX_ENV=dev
APP_NAME_SUFFIX=dev
```

**Tips:**
- `RESOURCE_SUFFIX` must be unique (used for resource naming)
- Use lowercase letters and numbers only
- Keep it short (max 10 characters)

### Step 2: Provision Azure Infrastructure

```powershell
cd M365Agent
atk provision --env dev
```

**What happens:**
1. Creates Teams app registration
2. Deploys Azure infrastructure via `azure.bicep`
3. Creates all 5 components (Identity → App Service → Bot → App Reg → OAuth)
4. Captures outputs in `.env.dev`
5. Builds and validates Teams app package
6. Registers app with Teams Developer Portal

**Expected output:**
```
✓ Teams app created
✓ Azure resources deployed
✓ Bot identity: <guid>
✓ Web app: https://botprod123-app.azurewebsites.net
✓ App package validated
```

### Step 3: Deploy Application Code

```powershell
atk deploy --env dev
```

**What happens:**
1. Builds .NET application (`dotnet publish`)
2. Uploads to Azure App Service
3. Bot is now live at the messaging endpoint

**Expected output:**
```
✓ Application published
✓ Deployed to App Service
✓ Bot endpoint: https://botprod123-app.azurewebsites.net/api/messages
```

### Step 4: Install in Teams

1. Open **Microsoft Teams**
2. Go to **Apps** → **Manage your apps**
3. Click **Upload an app** → **Upload a custom app**
4. Select: `M365Agent/appPackage/build/appPackage.dev.zip`
5. Click **Add**

### Step 5: Test Your Agent

1. In Teams, open your app
2. Send a message: "How can you help me?"
3. The bot should respond with available capabilities

## Verify Deployment

### Check Azure Resources

```powershell
# List all resources in your resource group
az resource list --resource-group rg-m365agent-prod --output table
```

You should see:
- User Assigned Managed Identity
- App Service Plan
- App Service (Web App)
- Bot Service

### Check OAuth Connection

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Bot Service
3. Go to **Configuration** → **OAuth Connection Settings**
4. Verify **SsoConnection** is listed
5. Click **Test Connection** and sign in

### Check App Registration

1. Go to [Azure Portal](https://portal.azure.com) → **Entra ID** → **App registrations**
2. Find your SSO app (name contains your RESOURCE_SUFFIX)
3. Verify:
   - **Expose an API** → `access_as_user` scope exists
   - **Authentication** → Federated credential exists
   - **API permissions** → Pre-authorized Teams clients

## Environment Variables Reference

After successful provisioning, these variables are populated in `.env.dev`:

| Variable | Description | Example |
|----------|-------------|---------|
| `BOT_ID` | Managed Identity Client ID (used as bot ID) | `12345678-1234-...` |
| `BOT_AZURE_APP_SERVICE_RESOURCE_ID` | App Service resource ID | `/subscriptions/.../webApp` |
| `webAppHostName` | App Service hostname | `botprod123-app.azurewebsites.net` |
| `AAD_APP_CLIENT_ID` | SSO app client ID | `87654321-4321-...` |
| `AAD_APP_ID_URI` | SSO app ID URI | `api://botid-<guid>` |
| `oauthConnectionName` | OAuth connection name | `SsoConnection` |

## Updating Your Deployment

### Update Infrastructure

If you change `azure.bicep` or parameters:

```powershell
atk provision --env dev
```

This is **safe to run multiple times** - it updates existing resources.

### Update Application Code

After making code changes:

```powershell
atk deploy --env dev
```

### Update Teams Manifest

After changing `manifest.json`:

```powershell
atk provision --env dev
```

Then re-upload the app package to Teams.

## Troubleshooting

### Provision Failed

**Error: "Deployment failed"**
- Check Azure CLI login: `az account show`
- Verify subscription ID is correct
- Check resource group permissions

**Error: "Resource name already exists"**
- Change `RESOURCE_SUFFIX` to a unique value
- Delete existing resources if they're no longer needed

### Deploy Failed

**Error: "Cannot find resource ID"**
- Run `atk provision` first
- Check `BOT_AZURE_APP_SERVICE_RESOURCE_ID` in `.env.dev`

### Bot Not Responding

**Check App Service logs:**
```powershell
az webapp log tail --name <webAppName> --resource-group <resourceGroup>
```

**Verify bot endpoint:**
- Go to Azure Portal → Bot Service → Settings
- Check **Messaging endpoint** matches your App Service URL + `/api/messages`

### SSO Not Working

**Test OAuth connection:**
1. Azure Portal → Bot Service → Configuration → OAuth Connection Settings
2. Click **Test Connection** for `SsoConnection`
3. Sign in with a test user
4. Should see "Success"

**If test fails:**
- Check federated credential in Entra ID app registration
- Verify `access_as_user` scope is configured
- Check Teams clients are pre-authorized

## Clean Up

To delete all Azure resources:

```powershell
az group delete --name rg-m365agent-prod --yes --no-wait
```

**Note:** This deletes ALL resources in the resource group.

## Cost Estimate

| Resource | SKU | Est. Cost (monthly) |
|----------|-----|---------------------|
| App Service Plan | B1 (Basic) | ~$13 |
| Bot Service | F0 (Free) | $0 |
| Managed Identity | - | $0 |
| App Registration | - | $0 |
| **Total** | | **~$13/month** |

**To reduce costs:**
- Use F1 (Free) App Service tier for development
- Scale up to S1/P1 for production workloads

## Next Steps

- ✅ [Configure application settings](../AzureAgentToM365ATK/appsettings.json)
- ✅ [Add Microsoft Graph permissions](DEPLOYMENT_GUIDE.md#sso-configuration)
- ✅ [Monitor with Application Insights](DEPLOYMENT_GUIDE.md#monitoring)

## Support

- 📖 [Full Deployment Guide](DEPLOYMENT_GUIDE.md)
- 📖 [Microsoft 365 Agents Toolkit Docs](https://aka.ms/m365agentstoolkit)
- 🐛 [Report Issues](https://github.com/ericsche/ProxyAgent/issues)
