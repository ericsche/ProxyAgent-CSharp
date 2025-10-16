// Azure App Service Module for .NET 9 Application
// This module deploys an App Service Plan and App Service with managed identity

@maxLength(20)
@minLength(4)
@description('Used to generate names for all resources in this file')
param resourceBaseName string

@description('The resource ID of the User Assigned Managed Identity')
param MSIid string 

@description('Location for all resources')
param location string = resourceGroup().location

@description('The name of the App Service Plan')
param serverfarmsName string = resourceBaseName

@description('The name of the Web App')
param webAppName string = resourceBaseName

@description('The SKU for the App Service Plan')
param webAppSKU string

@description('Additional app settings for the Web App')
param additionalAppSettings array = []

@description('Enable Application Insights')
param enableAppInsights bool = true

@description('Application Insights instrumentation key (optional)')
param appInsightsInstrumentationKey string = ''

@description('Application Insights connection string (optional)')
param appInsightsConnectionString string = ''

// App Service Plan - Compute resources for your Web App
resource serverfarm 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: serverfarmsName
  location: location
  kind: 'app,linux'
  sku: {
    name: webAppSKU
  }
  properties: {
    reserved: true // Required for Linux
  }
}

// Web App that hosts your .NET 9 agent
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: serverfarm.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      linuxFxVersion: 'DOTNETCORE|9.0'
      healthCheckPath: '/health'
      appSettings: concat([
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: reference(MSIid, '2023-01-31').clientId
        }
      ], enableAppInsights && !empty(appInsightsConnectionString) ? [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
      ] : [], enableAppInsights && !empty(appInsightsInstrumentationKey) ? [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
      ] : [], additionalAppSettings)
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
          'https://ms.portal.azure.com'
        ]
        supportCredentials: false
      }
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${MSIid}': {}
    }
  }
}

// Outputs for use in other modules
output webAppName string = webApp.name
output webAppId string = webApp.id
output webAppHostName string = webApp.properties.defaultHostName
output webAppPrincipalId string = reference(MSIid, '2023-01-31').principalId
output appServicePlanId string = serverfarm.id
