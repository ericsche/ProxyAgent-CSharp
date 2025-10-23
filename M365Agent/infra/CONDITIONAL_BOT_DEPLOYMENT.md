# Idempotent Bot Service Deployment

## Overview

The `azure-local.bicep` now uses **idempotent deployment** - it automatically:
- ✅ **Creates a new bot service** (if it doesn't exist)
- ✅ **Updates the bot endpoint** (if it already exists)

No parameters needed - Bicep handles it automatically!

## How It Works

### Idempotent Resource Deployment

The bot service is now declared as a direct resource in the Bicep file:

```bicep
resource botService 'Microsoft.BotService/botServices@2021-03-01' = {
  kind: 'azurebot'
  location: 'global'
  name: botServiceName
  properties: {
    displayName: botName
    endpoint: botEndpoint  // Updated on every deployment
    msaAppId: botId
    msaAppTenantId: tenantId
    msaAppType: 'SingleTenant'
  }
  sku: {
    name: botServiceSku
  }
}
```

**Azure Resource Manager automatically:**
- Creates the bot if it doesn't exist
- Updates the endpoint (and other properties) if it does exist

## Usage Scenarios

### Every Deployment (First Time or Update)

Simply run the deployment - no special parameters needed:

```powershell
atk provision --env local
# OR
az deployment group create \
  --resource-group rg-m365agent-local \
  --template-file azure-local.bicep \
  --parameters azure-local.parameters.json
```

**What happens automatically:**
1. ✅ SSO App Registration (created or updated)
2. ✅ Azure Bot Service (created if new, endpoint updated if exists)
3. ✅ OAuth Connection (created or updated)

## Step-by-Step: Updating Bot Endpoint

### 1. Your dev tunnel URL changes
```bash
# Old tunnel
BOT_ENDPOINT=https://abc123.devtunnels.ms:5000/api/messages

# New tunnel (after restart)
BOT_ENDPOINT=https://xyz789.devtunnels.ms:5000/api/messages
```

### 2. Update `.env.local`
```bash
BOT_ENDPOINT=https://xyz789.devtunnels.ms:5000/api/messages
```

### 3. Change `createNewBot` to `false`

**Option A: Edit parameters file**
```json
{
  "parameters": {
    "createNewBot": {
      "value": false  // Changed from true to false
    }
  }
}
```

**Option B: Override in command line**
```powershell
az deployment group create `
  --resource-group rg-m365agent-local `
  --template-file azure-local.bicep `
  --parameters azure-local.parameters.json `
  --parameters createNewBot=false
```

### 4. Run deployment
```powershell
atk provision --env local
```

## What Happens Under the Hood

### When `createNewBot = true`:
```
✅ Deploy SSO App Registration module
✅ Deploy azurebot-local.bicep module (creates new bot)
❌ Skip update-bot-endpoint.bicep module
✅ Deploy OAuth Connection module
```

### When `createNewBot = false`:
```
✅ Deploy SSO App Registration module
❌ Skip azurebot-local.bicep module (bot already exists)
✅ Deploy update-bot-endpoint.bicep module (updates endpoint)
✅ Deploy OAuth Connection module
```

## Benefits

### ✅ Faster Updates
- Only updates what changed (endpoint)
- No need to recreate entire bot service

### ✅ Preserves Configuration
- Keeps existing bot channels
- Maintains OAuth connections
- Preserves settings

### ✅ Less API Calls
- Fewer Azure operations
- Faster provision time

### ✅ Safe Idempotency
- Can run multiple times safely
- Won't fail if bot exists

## Files Created

### `modules/update-bot-endpoint.bicep`
A new module that updates an existing bot service with:
- New messaging endpoint
- Same bot ID
- Same tenant configuration

The key difference: it performs an **update** operation on existing resource rather than creating new one.

## Common Workflows

### Workflow 1: Initial Setup
1. Set `createNewBot = true`
2. Run `atk provision --env local`
3. Bot service created ✅

### Workflow 2: Dev Tunnel Restarts
1. Dev tunnel URL changes
2. Update `BOT_ENDPOINT` in `.env.local`
3. Set `createNewBot = false`
4. Run `atk provision --env local`
5. Bot endpoint updated ✅

### Workflow 3: Complete Rebuild
1. Delete resource group
2. Set `createNewBot = true`
3. Run `atk provision --env local`
4. Everything recreated ✅

## Troubleshooting

### Error: "Resource already exists"
- You have `createNewBot = true` but bot already exists
- **Fix**: Change to `createNewBot = false`

### Error: "Resource not found"
- You have `createNewBot = false` but bot doesn't exist
- **Fix**: Change to `createNewBot = true`

### How to check if bot exists?
```powershell
az bot show --name AzureAgentToM365ATK-local --resource-group rg-m365agent-local
```

## Best Practice

**Recommended approach:**
1. First deployment: `createNewBot = true`
2. Subsequent deploys (tunnel changes): `createNewBot = false`
3. Keep `true` as default in parameters file for clean slate deployments

## Advanced: Auto-Detection

If you want to automatically detect if the bot exists, you could add this logic to your YAML pipeline or use a pre-deployment script, but the manual parameter approach gives you more control.
