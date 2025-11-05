# Local Development Deployment Guide

Complete guide for setting up and debugging your M365 Agent in a local development environment.

---

## Table of Contents
- [Overview](#overview)
- [Key Differences from Production](#key-differences-from-production)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Development Workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## Overview

Local deployment is optimized for debugging and rapid development. Instead of deploying to Azure App Service, your bot runs on your local machine while still using Azure Bot Service for Teams connectivity.

**Key Features:**
- ✅ Run and debug locally in VS Code or Visual Studio
- ✅ Fast iteration (no deployment wait times)
- ✅ Full debugging support with breakpoints
- ✅ Uses devtunnel for secure local endpoint exposure
- ✅ Minimal Azure costs (only Bot Service required)
- ✅ SSO with federated credentials (no client secrets for SSO)

**Deployment Files:**
- `infra/azure-local.bicep` - Local infrastructure template
- `infra/azure-local.parameters.json` - Parameter configuration
- `m365agents.local.yml` - Microsoft 365 Agents Toolkit orchestration for local

---

## Key Differences from Production

| Feature | Production Deployment | Local Development |
|---------|----------------------|-------------------|
| **Bot Hosting** | Azure App Service | Local machine (VS Code/Visual Studio) |
| **Bot Identity** | User Assigned Managed Identity | App Registration with Client Secret |
| **Bot Auth** | UserAssignedMSI | SingleTenant + Client Secret |
| **Endpoint** | Static Azure URL | Dynamic devtunnel URL |
| **SSO App** | Federated Credentials | Federated Credentials |
| **Cost** | ~$13-100/month | Bot Service only (~$0 with F0) |
| **Debugging** | Remote (limited) | Full local debugging |
| **Deployment** | `atk deploy` required | Run locally (F5) |
| **Iteration Speed** | 2-3 minutes | Instant |

---

## Architecture

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
│  Step 2: Azure Bot Service ↓                                  │
│  ┌──────────────────────────────────┐                         │
│  │ Bot Service                      │                         │
│  │ - Single Tenant Auth             │                         │
│  │ - Teams Channel                  │                         │
│  │ - Dynamic Endpoint (devtunnel)   │                         │
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
                       ↓ (Secure tunnel)
                       
            Local Development Machine
        ┌──────────────────────────────┐
        │  .NET 9 Bot Application      │
        │  - VS Code / Visual Studio   │
        │  - Debugger Attached         │
        │  - Port: 5000 or 7071        │
        │  - devtunnel running         │
        └──────────────────────────────┘
```

---

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| **Azure CLI** | Latest | [Install Guide](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| **Microsoft 365 Agents Toolkit CLI** | Latest | [Install Guide](https://aka.ms/m365agentstoolkit-cli) |
| **.NET SDK** | 9.0 | [Download](https://dotnet.microsoft.com/download/dotnet/9.0) |
| **Visual Studio Code** | Latest | [Download](https://code.visualstudio.com/) |
| **Dev Tunnels CLI** | Latest | [Install Guide](https://learn.microsoft.com/azure/developer/dev-tunnels/get-started) |

**Installation Commands:**
```powershell
# Azure CLI
winget install Microsoft.AzureCLI

# Microsoft 365 Agents Toolkit CLI
npm install -g @microsoft/m365agentstoolkit-cli

# Dev Tunnels CLI
winget install Microsoft.devtunnel

# Verify installations
az --version
atk --version
dotnet --version
devtunnel --version
```

### Required VS Code Extensions

Install these extensions in VS Code:
- **Microsoft 365 Agents Toolkit** (`ms-teams-vscode.ms-teams-vscode-extension`)
- **C# Dev Kit** (`ms-dotnettools.csdevkit`)
- **Azure Account** (`ms-vscode.azure-account`)

### Required Azure Permissions

| Permission | Scope | Purpose |
|------------|-------|---------|
| **Contributor** | Subscription or Resource Group | Deploy Bot Service |
| **Application Administrator** | Entra ID | Create app registrations |

---

## Quick Start

### Step 1: Clone and Open Project

```powershell
# Navigate to project
cd c:\Users\ericsche\source\repos\ericsche\ProxyAgent\M365Agent

# Open in VS Code
code .
```

### Step 2: Configure Environment Variables

Edit `M365Agent/env/.env.local`:

```bash
# ============================================================================
# Azure Configuration (REQUIRED for ARM deployment)
# ============================================================================
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
AZURE_RESOURCE_GROUP_NAME=rg-m365agent-local

# ============================================================================
# SSO App ID (Controls deployment mode)
# ============================================================================
# First time: Use null GUID
# Updates: Use actual GUID from previous deployment
SSO_APP_ID=00000000-0000-0000-0000-000000000000

# ============================================================================
# Bot Configuration (Auto-populated during provision)
# ============================================================================
BOT_ID=
BOT_ENDPOINT=
TEAMS_APP_TENANT_ID=

# ============================================================================
# Output Variables (Auto-populated by atk provision)
# ============================================================================
# These are set automatically - do not edit manually
```

**Finding your subscription ID:**
```powershell
az login
az account show --query id -o tsv
```

### Step 3: Create Dev Tunnel

```powershell
# Create a persistent dev tunnel (first time only)
devtunnel create --allow-anonymous

# Example output:
# Created tunnel: giant-fog-9lvr5gd

# Start hosting the tunnel
devtunnel port create -p 5000
devtunnel host

# Copy the HTTPS URL from output
# Example: https://giant-fog-9lvr5gd-5000.euw.devtunnels.ms
```

**Keep this terminal open** - the tunnel needs to stay running while you develop.

### Step 4: Provision Azure Resources

In VS Code:
1. Open the **Microsoft 365 Agents Toolkit** sidebar
2. Click **Provision** in the **LIFECYCLE** section
3. Select **local** environment
4. Wait for provisioning to complete (~3-5 minutes)

**OR** via CLI:
```powershell
cd M365Agent
atk provision --env local
```

**What gets created:**
1. ✅ Teams App registration
2. ✅ Bot App Registration (Entra ID)
3. ✅ Azure Bot Service
4. ✅ SSO App Registration (Entra ID)
5. ✅ OAuth Connection
6. ✅ Teams app package

**Expected output:**
```
✓ Teams app created
✓ Bot App Registration created
✓ Azure Bot Service created
✓ SSO App Registration created
✓ OAuth Connection configured
✓ Environment variables updated in .env.local
✓ Provision completed successfully
```

### Step 5: Create Client Secret

After provisioning, you need to manually create a client secret for the bot:

1. Go to [Azure Portal](https://portal.azure.com) → **Entra ID** → **App Registrations**
2. Find your bot app (e.g., `AzureAgentToM365ATK-local`)
3. Go to **Certificates & secrets**
4. Click **New client secret**
5. Description: `Local Development`
6. Expires: **180 days** (or custom)
7. Click **Add**
8. **Copy the secret value immediately!** (You won't see it again)

### Step 6: Configure Application Settings

Create or update `AzureAgentToM365ATK/appsettings.Development.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.Hosting.Lifetime": "Information"
    }
  },
  "MicrosoftAppType": "SingleTenant",
  "MicrosoftAppId": "<BOT_ID from .env.local>",
  "MicrosoftAppPassword": "<client secret from Step 5>",
  "MicrosoftAppTenantId": "<TEAMS_APP_TENANT_ID from .env.local>",
  "ConnectionName": "SsoConnection"
}
```

**Important:** Never commit `appsettings.Development.json` with secrets to source control!

### Step 7: Run and Debug

In VS Code:
1. Press **F5** (or click **Debug** → **Start Debugging**)
2. Select **Debug in Microsoft 365 Agents Playground (local)** if prompted
3. Your bot should start on `http://localhost:5000`
4. Microsoft 365 Agents Playground opens automatically
5. Send a message to your bot!

**OR** via CLI:
```powershell
# In one terminal - keep dev tunnel running
devtunnel host

# In another terminal - run the bot
cd AzureAgentToM365ATK
dotnet run
```

---

## Detailed Setup

### Understanding Conditional Deployment

The local deployment uses a conditional deployment strategy based on the `SSO_APP_ID` parameter:

#### First-Time Deployment
When `SSO_APP_ID = 00000000-0000-0000-0000-000000000000`:
- ✅ Creates Bot Service
- ✅ Creates SSO App Registration with Federated Credentials
- ✅ Creates OAuth Connection
- ✅ Saves SSO_APP_ID to `.env.local`

#### Update Deployment
When `SSO_APP_ID` is a real GUID (from previous deployment):
- ✅ Updates Bot Service endpoint only
- ⏭️ Skips SSO App Registration (already exists)
- ⏭️ Skips OAuth Connection (already exists)

**Why this matters:**
- First provision: Takes 3-5 minutes, creates all resources
- Updates: Takes ~1 minute, only updates bot endpoint
- You can change your devtunnel URL without recreating SSO resources

### Bot App Registration Details

**Module:** `modules/bot-app-registration.bicep`

**Purpose:** Creates the Entra ID application that serves as the bot's identity (replaces managed identity for local dev).

**Configuration:**
```bicep
Sign-in Audience: AzureADMyOrg (Single tenant)
Authentication: Client ID + Client Secret
```

**Why Client Secret?**
- Managed Identity requires Azure App Service
- Local development needs a different auth mechanism
- Client Secret is suitable for dev (not recommended for production)

**Outputs:**
- `botAppId`: Use as `BOT_ID` and `MicrosoftAppId`
- `botAppObjectId`: Object ID of the application

### Bot Service Configuration

**Module:** `modules/azurebot.bicep`

**Purpose:** Registers your local service as a bot with Bot Framework.

**Key Settings:**
```bicep
Kind: azurebot
Location: global
SKU: F0 (Free tier)
MSA App Type: SingleTenant
Endpoint: Dynamic (your devtunnel URL)
```

**Endpoint Updates:**
Every time you run `atk provision --env local`, the bot endpoint is updated to your current devtunnel URL. This allows you to:
- Restart your tunnel with a new URL
- Switch between different tunnel configurations
- Update without recreating other resources

### SSO App Registration

**Module:** `modules/app-registration.bicep`

**Purpose:** Enables Single Sign-On for user authentication.

**Configuration:**
```bicep
OAuth Scope: access_as_user
Federated Credentials: Yes (Bot Framework issuer)
Pre-authorized Clients: Teams clients
```

**Federated Credentials Subject:**
```
/eid1/c/pub/t/{encodedTenantId}/a/{encodedAppId}/{uniqueId}
```

The GUID encoder module handles the encoding automatically.

### OAuth Connection

**Module:** `modules/bot-oauth-connection.bicep`

**Purpose:** Connects the bot to the SSO app for token exchange.

**Configuration:**
```bicep
Service Provider: Azure Active Directory v2
Client ID: SSO App ID
Scopes: openid profile offline_access
Federated Credentials: true
```

---

## Development Workflow

### Daily Development Cycle

1. **Start Dev Tunnel**
   ```powershell
   devtunnel host
   ```

2. **If tunnel URL changed, update Bot Service**
   ```powershell
   # If needed (tunnel URL changed)
   atk provision --env local
   ```

3. **Run Bot**
   ```powershell
   # In VS Code
   Press F5
   
   # OR via CLI
   cd AzureAgentToM365ATK
   dotnet run
   ```

4. **Test in Teams**
   - Open Microsoft 365 Agents Playground
   - Send messages to your bot
   - Set breakpoints in VS Code
   - Debug as needed

5. **Make Changes**
   - Edit code
   - Save files
   - Hot reload kicks in (or restart debugger)
   - Test immediately

### Testing SSO Flow

1. **Trigger Authentication**
   ```csharp
   // In your bot code
   var tokenResponse = await turnContext.Adapter.GetUserTokenAsync(
       turnContext,
       "SsoConnection", // Must match OAuth connection name
       null,
       cancellationToken);
   ```

2. **Expected Flow**
   - User sends message requiring auth
   - Bot sends OAuth card
   - User clicks "Sign In"
   - SSO kicks in (no additional prompts if configured correctly)
   - Bot receives token

3. **Debugging SSO Issues**
   - Check `ConnectionName` in `appsettings.Development.json`
   - Verify `webApplicationInfo` in manifest
   - Check federated credentials in Azure Portal
   - Review pre-authorized clients

### Working with Multiple Developers

Each developer should:
1. Create their own dev tunnel
2. Have their own `.env.local` with their tunnel URL
3. Run `atk provision --env local` to register their endpoint
4. Use their own client secret

**Shared Resources:**
- Azure Bot Service (shared registration, multiple endpoints)
- SSO App Registration (shared, single instance)
- Teams App (shared, single registration)

---

## Troubleshooting

### Bot Not Responding

**Check 1: Dev Tunnel Running**
```powershell
# Verify tunnel is active
devtunnel show
```

**Check 2: Bot Application Running**
```powershell
# Check if bot is listening
curl http://localhost:5000/health
```

**Check 3: Bot Endpoint Configured**
```powershell
# Verify bot endpoint in Azure
az bot show --name <bot-name> --resource-group <rg-name> --query properties.endpoint
```

**Check 4: Application Logs**
Look at the console output where you ran `dotnet run` or the Debug Console in VS Code.

---

### "401 Unauthorized" from Bot Service

**Cause:** Bot authentication is not configured correctly.

**Solution:**
1. Verify `appsettings.Development.json`:
   ```json
   {
     "MicrosoftAppType": "SingleTenant",
     "MicrosoftAppId": "<matches BOT_ID>",
     "MicrosoftAppPassword": "<valid client secret>",
     "MicrosoftAppTenantId": "<matches TEAMS_APP_TENANT_ID>"
   }
   ```

2. Verify client secret hasn't expired:
   - Go to Azure Portal → App Registrations
   - Find bot app → Certificates & secrets
   - Check expiration date
   - Create new secret if expired

3. Restart your bot application

---

### SSO Not Working

**Check 1: Manifest Configuration**
Verify `appPackage/build/manifest.local.json`:
```json
{
  "webApplicationInfo": {
    "id": "<matches SSO_APP_ID>",
    "resource": "<matches SSO_APP_ID_URI>"
  }
}
```

**Check 2: OAuth Connection**
```powershell
az bot authsetting show `
  --name <bot-name> `
  --resource-group <rg-name> `
  --setting-name SsoConnection
```

**Check 3: Federated Credentials**
1. Go to Azure Portal → Entra ID → App Registrations
2. Find SSO app
3. Go to **Certificates & secrets** → **Federated credentials**
4. Should see credential with:
   - Issuer: `https://token.botframework.com/`
   - Subject: `/eid1/c/pub/t/...`

**Check 4: Pre-authorized Clients**
1. In SSO App Registration → **Expose an API**
2. Check **Authorized client applications**
3. Should include Teams client IDs:
   - `1fec8e78-bce4-4aaf-ab1b-5451cc387264` (Teams mobile/desktop)
   - `5e3ce6c0-2b1f-4285-8d4b-75ee78787346` (Teams web)

---

### Dev Tunnel Issues

**Problem: Tunnel disconnects frequently**

**Solution:**
- Use persistent tunnel: `devtunnel create --allow-anonymous`
- Keep terminal window open
- Consider using `devtunnel host --background`

**Problem: "Tunnel not found"**

**Solution:**
```powershell
# List your tunnels
devtunnel list

# Delete and recreate
devtunnel delete <tunnel-id>
devtunnel create --allow-anonymous
```

---

### Provision Failed: "SSO_APP_ID is invalid"

**Cause:** The SSO_APP_ID in `.env.local` is not a valid GUID.

**Solution:**
For first-time provisioning, use the null GUID:
```bash
SSO_APP_ID=00000000-0000-0000-0000-000000000000
```

For updates, use the actual GUID from the previous deployment:
```bash
SSO_APP_ID=a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

---

### Cannot Create Client Secret

**Problem:** No "Certificates & secrets" menu option.

**Cause:** Insufficient permissions in Entra ID.

**Solution:**
- Contact your Azure AD administrator
- Need **Application Administrator** role
- Or have admin create the secret for you

---

### Hot Reload Not Working

**Solution:**
1. Make sure you're using .NET 9.0
2. Run with `dotnet watch run` instead of `dotnet run`
3. Or use VS Code debugger with hot reload enabled

---

## Advanced Configuration

### Using a Custom Port

If port 5000 is already in use:

1. **Update launchSettings.json**
   ```json
   {
     "profiles": {
       "AzureAgentToM365ATK": {
         "applicationUrl": "http://localhost:7071"
       }
     }
   }
   ```

2. **Update Dev Tunnel**
   ```powershell
   devtunnel port create -p 7071
   devtunnel host
   ```

3. **Re-provision**
   ```powershell
   atk provision --env local
   ```

### Multiple Local Environments

Create separate local environments for different scenarios:

```bash
# .env.local - Default
SSO_APP_ID=00000000-0000-0000-0000-000000000000

# .env.local.test - Testing with test tenant
SSO_APP_ID=00000000-0000-0000-0000-000000000000

# .env.local.staging - Staging-like local env
SSO_APP_ID=00000000-0000-0000-0000-000000000000
```

Provision each:
```powershell
atk provision --env local
atk provision --env local.test
atk provision --env local.staging
```

### Using ngrok Instead of devtunnel

If you prefer ngrok:

1. **Install ngrok**
   ```powershell
   winget install ngrok
   ```

2. **Start ngrok**
   ```powershell
   ngrok http 5000
   ```

3. **Use ngrok URL**
   Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`)

4. **Update .env.local**
   ```bash
   BOT_ENDPOINT=https://abc123.ngrok.io/api/messages
   ```

5. **Provision**
   ```powershell
   atk provision --env local
   ```

### Debugging with Multiple Breakpoints

**VS Code Tips:**

1. **Conditional Breakpoints**
   - Right-click breakpoint → Edit Breakpoint
   - Add condition: `message.Text.Contains("hello")`

2. **Logpoints**
   - Right-click in gutter → Add Logpoint
   - Log message without stopping: `Message: {message.Text}`

3. **Debug Console**
   - Evaluate expressions while debugging
   - Example: `turnContext.Activity.Text`

### Environment-Specific Configuration

Use different `appsettings.*.json` files:

```
appsettings.json                    # Base configuration
appsettings.Development.json        # Local dev (with secrets)
appsettings.Staging.json           # Staging environment
appsettings.Production.json        # Production (no secrets!)
```

Set environment in `launchSettings.json`:
```json
{
  "profiles": {
    "Development": {
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "Staging": {
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Staging"
      }
    }
  }
}
```

---

## Cost Summary

### Azure Resources (Local Development)

| Resource | SKU | Monthly Cost |
|----------|-----|--------------|
| Azure Bot Service | F0 (Free) | **$0** |
| App Registrations | - | $0 |
| Dev Tunnel | - | $0 |
| **Total** | | **$0/month** |

**Notes:**
- F0 Bot Service limited to 10,000 messages/month
- Upgrade to S1 if you exceed the limit (~$0.50 per 1,000 messages)
- No App Service costs (running locally)
- No compute costs in Azure

---

## Best Practices

### Security

✅ **Never commit secrets to source control**
- Add `appsettings.Development.json` to `.gitignore`
- Use User Secrets for sensitive data
- Rotate client secrets regularly

✅ **Use federated credentials for SSO**
- No secrets needed for user authentication
- More secure than client secrets
- Automatic token exchange

✅ **Limit client secret lifetime**
- Use 180 days or less
- Set calendar reminders for rotation
- Consider using Azure Key Vault for secrets

### Development

✅ **Use persistent dev tunnels**
- Create once, reuse multiple times
- Reduces need to re-provision
- Faster iteration

✅ **Keep dependencies updated**
- Regularly update NuGet packages
- Update .NET SDK
- Update toolkit CLI

✅ **Use structured logging**
```csharp
_logger.LogInformation("User {UserId} sent message: {Message}", 
    userId, message.Text);
```

✅ **Implement health checks**
```csharp
app.MapGet("/health", () => "OK");
```

### Testing

✅ **Test SSO flow thoroughly**
- Test first-time login
- Test token refresh
- Test error scenarios

✅ **Test different message types**
- Text messages
- Adaptive cards
- File uploads
- Message reactions

✅ **Test Teams scenarios**
- Personal chat
- Group chat
- Team channel

---

## Transitioning to Production

When ready to move from local development to production:

1. **Switch to production deployment**
   ```powershell
   # Follow AZURE_DEPLOYMENT.md guide
   atk provision --env dev
   atk deploy --env dev
   ```

2. **Update configuration**
   - Remove client secrets
   - Use Managed Identity
   - Enable Application Insights
   - Configure auto-scaling

3. **Update manifest**
   - Point to production domains
   - Update app icons and descriptions
   - Submit for app store (if applicable)

4. **Set up CI/CD**
   - GitHub Actions or Azure DevOps
   - Automated testing
   - Automated deployment

---

## Summary

You're all set for local M365 Agent development! 🚀

**Quick Recap:**
1. ✅ Create dev tunnel
2. ✅ Provision Azure resources (`atk provision --env local`)
3. ✅ Create client secret in Azure Portal
4. ✅ Configure `appsettings.Development.json`
5. ✅ Press F5 and start debugging!

**Development Workflow:**
1. Start dev tunnel
2. Press F5 to run bot
3. Test in Microsoft 365 Agents Playground
4. Make changes → Save → Test
5. Repeat!

**Resources:**
- [Microsoft 365 Agents Toolkit Documentation](https://aka.ms/teams-toolkit-docs)
- [Bot Framework SDK](https://github.com/microsoft/botbuilder-dotnet)
- [Dev Tunnels Documentation](https://learn.microsoft.com/azure/developer/dev-tunnels/)
- [Teams App Development](https://learn.microsoft.com/microsoftteams/platform/)

**Support:**
- GitHub Issues: [Teams Toolkit Repository](https://github.com/OfficeDev/TeamsFx/issues)
- Microsoft Q&A: [Teams Development](https://learn.microsoft.com/answers/topics/microsoft-teams.html)
