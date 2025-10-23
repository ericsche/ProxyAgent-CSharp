// Service Principal Creation Module
// Creates a service principal for an existing App Registration
// This is required for the Bot Service to work with SingleTenant authentication

extension microsoftGraphV1

@description('The App ID (Client ID) of the existing application registration')
param appId string

@description('Display name for the service principal')
param displayName string

// Create Service Principal for the existing application
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: appId
  accountEnabled: true
  displayName: displayName
  servicePrincipalType: 'Application'
  tags: [
    'WindowsAzureActiveDirectoryIntegratedApp'
  ]
}

// Outputs
output servicePrincipalId string = servicePrincipal.id
output servicePrincipalObjectId string = servicePrincipal.id
output appId string = servicePrincipal.appId
