# Quick Reference: ssoAppId Conditional Deployment

## The Simple Rule
```bash
SSO_APP_ID="00000000-0000-0000-0000-000000000000"  → First-time: Create Bot + SSO + OAuth
SSO_APP_ID="<actual-guid>"                         → Update: Only update Bot endpoint
```

## First Time (Create Everything)
```bash
# .env.local
SSO_APP_ID=00000000-0000-0000-0000-000000000000

# Run
atk provision --env local

# Result
✅ Bot Service created
✅ SSO App Registration created
✅ OAuth Connection created
✅ SSO_APP_ID saved to .env.local
```

## Update (Endpoint Only)
```bash
# .env.local (after first deployment)
SSO_APP_ID=a1b2c3d4-e5f6-7890-abcd-ef1234567890

# Change endpoint
BOT_ENDPOINT=https://new-tunnel.devtunnels.ms/api/messages

# Run
atk provision --env local

# Result
✅ Bot endpoint updated
⏭️ SSO App skipped (already exists)
⏭️ OAuth Connection skipped (already exists)
```

## Check Deployment Mode
Look at the deployment output:
```json
{
  "deploymentMode": "First-time (created all resources)"
  // or
  "deploymentMode": "Update (bot endpoint only)"
}
```

## Files Changed
- `azure-local.bicep` - Conditional logic
- `azure-local.parameters.json` - Added ssoAppId parameter
- `.env.local` - SSO_APP_ID variable

## Verify
```bash
# Compile check
az bicep build --file azure-local.bicep

# Should show only 1 warning (guid-encoder) - that's OK!
```
