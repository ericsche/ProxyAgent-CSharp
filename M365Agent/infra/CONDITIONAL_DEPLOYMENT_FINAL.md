# Conditional Deployment with ssoAppId Parameter

## Overview
The `azure-local.bicep` file now supports two deployment modes based on the `ssoAppId` parameter:

### First-Time Deployment (ssoAppId is empty string)
When `ssoAppId = ''` (default value):
- ✅ Creates Bot Service
- ✅ Creates SSO App Registration with Federated Credentials
- ✅ Creates OAuth Connection
- ✅ Returns all resource IDs as outputs

### Update Deployment (ssoAppId is a GUID)
When `ssoAppId` is a GUID (e.g., from previous deployment):
- ✅ Updates Bot Service endpoint only
- ⛔ Skips SSO App Registration creation
- ⛔ Skips OAuth Connection creation
- ✅ Returns the provided ssoAppId in outputs

## Parameters

### Required Parameters
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `botName` | string | Display name for the bot | `"AzureAgentToM365ATK"` |
| `botId` | string | Bot ID (GUID) from Entra App Registration | `"e3a05a20-..."` |
| `botEndpoint` | string | HTTPS URL for bot messages | `"https://...devtunnels.ms/api/messages"` |
| `tenantId` | string | Entra ID Tenant ID | `"671740f0-..."` |

### Optional Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ssoAppId` | string | `''` | SSO App ID - empty for first-time, GUID for updates |
| `botServiceSku` | string | `'F0'` | Bot Service SKU (F0=Free, S1=Standard) |

## Environment Variables

### .env.local File
```bash
# Azure Subscription (required for deployment)
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
AZURE_RESOURCE_GROUP_NAME=<your-resource-group>

# Bot Configuration (auto-generated during provision)
BOT_ID=e3a05a20-0b2c-4a75-9992-64d7a345317a
BOT_ENDPOINT=https://giant-fog-9lvr5gd-7071.euw.devtunnels.ms/api/messages
TEAMS_APP_TENANT_ID=671740f0-0ce9-4b51-bae5-4096de8b66d3

# SSO App ID - Controls deployment mode
# Use null GUID (00000000-0000-0000-0000-000000000000) for first-time deployment
# Set to actual GUID after first deployment for update-only mode
SSO_APP_ID=00000000-0000-0000-0000-000000000000
```

## Deployment Workflow

### First Time Setup
1. Ensure `.env.local` has `SSO_APP_ID=` (empty)
2. Run: `atk provision --env local`
3. Deployment creates:
   - Bot Service
   - SSO App Registration with Federated Credentials
   - OAuth Connection
4. Save the output `SSO_APP_ID` value to `.env.local`

### Subsequent Updates (Endpoint Changes)
1. Update `BOT_ENDPOINT` in `.env.local` (e.g., new dev tunnel)
2. Ensure `.env.local` has `SSO_APP_ID=<guid-from-first-deployment>`
3. Run: `atk provision --env local`
4. Deployment only updates:
   - Bot Service endpoint

## Implementation Details

### Conditional Logic
```bicep
// Parameter with default value
param ssoAppId string = ''

// Derived variable for readability
var isFirstTimeDeployment = empty(ssoAppId)

// Conditional modules (only deployed when isFirstTimeDeployment = true)
module ssoAppRegistration 'modules/app-registration.bicep' = if (isFirstTimeDeployment) {
  // ... module definition
}

module botOAuthConnection 'modules/bot-oauth-connection.bicep' = if (isFirstTimeDeployment) {
  // ... module definition
}

// Bot Service is always deployed (idempotent)
resource botService 'Microsoft.BotService/botServices@2021-03-01' = {
  // Always runs - safe to run multiple times
  properties: {
    endpoint: botEndpoint  // Updates endpoint every time
  }
}
```

### Safe Output Handling
Uses ternary operators with non-null assertion (`!`) to handle conditional module outputs:

```bicep
// Return module output on first-time, else return parameter
output ssoAppId string = isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppId : ssoAppId
output ssoAppObjectId string = isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppObjectId : ''
output ssoAppIdUri string = isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppIdUri : ''

// OAuth outputs only available on first-time
output oauthConnectionName string = isFirstTimeDeployment ? botOAuthConnection!.outputs.connectionName : 'SsoConnection'
output oauthConnectionId string = isFirstTimeDeployment ? botOAuthConnection!.outputs.connectionId : ''
```

The `!` operator asserts that the module is non-null when the condition is true.

### Deployment Summary Output
```bicep
output localDevSummary object = {
  botName: botName
  botServiceName: botService.name
  botEndpoint: botEndpoint
  botId: botId
  tenantId: tenantId
  ssoAppId: isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppId : ssoAppId
  ssoAppIdUri: isFirstTimeDeployment ? ssoAppRegistration!.outputs.aadAppIdUri : ''
  oauthConnectionName: 'SsoConnection'
  deploymentMode: isFirstTimeDeployment ? 'First-time (created all resources)' : 'Update (bot endpoint only)'
}
```

## Benefits

### 1. Clear Deployment Modes
- Empty `ssoAppId` = Create everything
- GUID `ssoAppId` = Update only
- No ambiguous boolean parameters

### 2. Fast Subsequent Deployments
- Update deployments skip SSO and OAuth creation
- Only updates bot endpoint (seconds instead of minutes)

### 3. Idempotent Bot Service
- Safe to run multiple times
- No "resource already exists" errors

### 4. Environment Persistence
- First deployment saves `SSO_APP_ID` to `.env.local`
- Subsequent runs use saved value automatically
- Clear indication of deployment state

## Troubleshooting

### "Resource already exists" Error
- Check if `SSO_APP_ID` in `.env.local` has a value
- If yes, you're in update mode (correct)
- If no, there may be leftover resources - check Azure Portal

### "Cannot access outputs of null module" Error
- Ensure all module output references use `!` operator
- Check that ternary conditions match module conditions
- Example: `isFirstTimeDeployment ? module!.outputs.value : defaultValue`

### Bot Endpoint Not Updating
- Verify `BOT_ENDPOINT` in `.env.local` has the new value
- Check that dev tunnel is running
- Confirm deployment completed successfully

## Testing

### Test First-Time Deployment
```bash
# Clean .env.local
SSO_APP_ID=

# Delete resources in Azure Portal if they exist
# Run provision
atk provision --env local

# Verify SSO_APP_ID is populated in .env.local
```

### Test Update Deployment
```bash
# Ensure SSO_APP_ID has a GUID value
SSO_APP_ID=<guid-from-previous-deployment>

# Change BOT_ENDPOINT to a new value
BOT_ENDPOINT=https://new-tunnel.devtunnels.ms/api/messages

# Run provision
atk provision --env local

# Verify only bot endpoint was updated (check deployment logs)
```

## Files Modified

1. **azure-local.bicep**
   - Added `ssoAppId` parameter with default value `''`
   - Added `isFirstTimeDeployment` variable
   - Made `ssoAppRegistration` module conditional
   - Made `botOAuthConnection` module conditional
   - Updated outputs with ternary operators and `!` assertions

2. **azure-local.parameters.json**
   - Added `ssoAppId` parameter: `"value": "${{SSO_APP_ID}}"`

3. **.env.local**
   - Added `SSO_APP_ID=` (empty by default)

4. **m365agents.local.yml**
   - Uses `arm/deploy` action with Bicep templates
   - Passes environment variables to parameters file

## Compilation Status
✅ **Bicep file compiles successfully** with only pre-existing warning about guid-encoder.bicep

```bash
az bicep build --file azure-local.bicep
# Warning: guid-encoder.bicep uses utcNow() (acceptable for this use case)
# No errors!
```
