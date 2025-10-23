# Updated m365agents.local.yml with Azure Deployment

## What Changed

The `botFramework/create` step has been **replaced** with an `arm/deploy` action that provisions:
1. ✅ SSO App Registration with Federated Credentials
2. ✅ Azure Bot Service (Single Tenant)
3. ✅ OAuth Connection with Federated Credentials

## Required Setup

### 1. Update Environment Variables

Edit `M365Agent/env/.env.local` and add your Azure subscription details:

```bash
# Azure Subscription and Resource Group (required for ARM deployment)
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
AZURE_RESOURCE_GROUP_NAME=<your-resource-group-name>
```

**To find your subscription ID:**
```powershell
az account show --query id -o tsv
```

**Create a resource group (if needed):**
```powershell
az group create --name rg-m365agent-local --location eastus
```

### 2. Login to Azure CLI

Make sure you're logged in:
```powershell
az login
az account set --subscription <your-subscription-id>
```

### 3. Run Provision

Now you can run the provision task as usual:

**Option A: Via VS Code**
- Press `F5` or use the "Start Teams App Locally" task
- The provision step will now deploy Azure resources automatically

**Option B: Via CLI**
```powershell
cd M365Agent
atk provision --env local
```

## What Gets Deployed

The ARM deployment will create:

| Resource | Name Pattern | Purpose |
|----------|-------------|---------|
| SSO App Registration | `AzureAgentToM365ATK-sso-local` | User authentication with federated credentials |
| Azure Bot Service | `AzureAgentToM365ATK-local` | Bot service using your BOT_ID |
| OAuth Connection | `SsoConnection` | Connects bot to SSO app |

## Environment Variables Populated

After successful deployment, these variables will be populated in `.env.local`:

```bash
BOT_SERVICE_NAME=AzureAgentToM365ATK-local
SSO_APP_ID=<guid>
SSO_APP_OBJECT_ID=<guid>
SSO_APP_ID_URI=api://<bot-domain>/<sso-app-id>
SSO_SERVICE_PRINCIPAL_ID=<guid>
OAUTH_CONNECTION_NAME=SsoConnection
```

## Benefits

### ✅ Automated Infrastructure
- No manual steps in Azure Portal
- Repeatable deployments
- Infrastructure as Code

### ✅ Federated Credentials
- No client secrets for SSO
- More secure
- Easier maintenance

### ✅ Single Tenant Bot
- Appropriate for enterprise scenarios
- Better security boundary

### ✅ Integrated with M365 Agents Toolkit
- Works seamlessly with existing provision flow
- Uses existing BOT_ID from toolkit
- Automatically configures OAuth

## Troubleshooting

### Error: "AZURE_SUBSCRIPTION_ID is empty"
- Add your subscription ID to `.env.local`
- Or set it in `.env.local.user` (not committed to git)

### Error: "Resource group not found"
- Create the resource group first: `az group create --name rg-m365agent-local --location eastus`
- Or update `AZURE_RESOURCE_GROUP_NAME` to an existing group

### Error: "Bicep deployment failed"
- Check Azure CLI is logged in: `az account show`
- Verify you have permissions to create resources in the subscription
- Check the deployment logs in Azure Portal

### Want to start fresh?
Delete the resource group and re-run provision:
```powershell
az group delete --name rg-m365agent-local --yes
atk provision --env local
```

## Next Steps

After successful provisioning:
1. ✅ Update your Teams app manifest with SSO_APP_ID and SSO_APP_ID_URI
2. ✅ Run your bot locally
3. ✅ Test SSO authentication in Teams

## Reverting to Old Approach

If you need to revert to the `botFramework/create` approach:
1. Remove the `arm/deploy` step
2. Add back the `botFramework/create` step
3. Remove Azure-specific environment variables
