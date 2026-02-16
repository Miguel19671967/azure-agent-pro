// ============================================================================
// App Service Module - Kitten Space Missions
// ============================================================================
// Crea App Service Plan + App Service con:
// - Managed Identity (SystemAssigned)
// - VNet Integration
// - Application Insights integration
// - Key Vault references
// - Auto-scaling configurado
// ============================================================================

@description('Nombre base para los recursos de App Service')
param name string

@description('Ubicación de Azure para los recursos')
param location string = resourceGroup().location

@description('Tags comunes para todos los recursos')
param tags object = {}

@description('SKU del App Service Plan')
param sku object = {
  name: 'B1'
  tier: 'Basic'
  capacity: 1
}

@description('Sistema operativo del App Service Plan')
@allowed([
  'Linux'
  'Windows'
])
param operatingSystem string = 'Linux'

@description('Runtime stack')
@allowed([
  'DOTNETCORE|8.0'
  'NODE|18-lts'
  'NODE|20-lts'
  'PYTHON|3.11'
])
param linuxFxVersion string = 'DOTNETCORE|8.0'

@description('ID de la subnet para VNet Integration')
param appSubnetId string

@description('ID del Application Insights')
param applicationInsightsId string

@description('Instrumentation Key del Application Insights')
param applicationInsightsInstrumentationKey string

@description('Connection String del Application Insights')
param applicationInsightsConnectionString string

@description('URI del Key Vault')
param keyVaultUri string

@description('Connection string de SQL (se almacenará en Key Vault)')
param sqlConnectionString string

@description('Nombre del Key Vault')
param keyVaultName string

@description('Habilitar auto-scaling')
param enableAutoScale bool = true

// Variables para nombres únicos globalmente
var appServiceName = 'app-km-${substring(uniqueString(resourceGroup().id), 0, 12)}'
var appServicePlanName = 'plan-km-${substring(uniqueString(resourceGroup().id), 0, 12)}'

// ============================================================================
// App Service Plan
// ============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: sku
  kind: operatingSystem == 'Linux' ? 'linux' : 'app'
  properties: {
    reserved: operatingSystem == 'Linux' ? true : false // true para Linux
    zoneRedundant: false // Dev no necesita zone redundancy
  }
}

// ============================================================================
// Auto-scaling Configuration
// ============================================================================

resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (enableAutoScale) {
  name: 'autoscale-${appServicePlanName}'
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceUri: appServicePlan.id
    profiles: [
      {
        name: 'Auto scale based on CPU'
        capacity: {
          minimum: '1'
          maximum: '3'
          default: '1'
        }
        rules: [
          // Scale out cuando CPU > 70%
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          // Scale in cuando CPU < 30%
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

// ============================================================================
// App Service
// ============================================================================

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: appServiceName
  location: location
  tags: tags
  kind: operatingSystem == 'Linux' ? 'app,linux' : 'app'
  identity: {
    type: 'SystemAssigned' // Managed Identity
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true // Solo HTTPS
    clientAffinityEnabled: false // Disable session affinity (mejor para stateless APIs)
    
    // VNet Integration
    virtualNetworkSubnetId: appSubnetId
    vnetRouteAllEnabled: true // Route all outbound traffic through VNet
    
    siteConfig: {
      linuxFxVersion: operatingSystem == 'Linux' ? linuxFxVersion : null
      alwaysOn: sku.tier != 'Free' && sku.tier != 'Shared' ? true : false
      ftpsState: 'Disabled' // Deshabilitar FTP/FTPS
      minTlsVersion: '1.2' // TLS 1.2 mínimo
      http20Enabled: true
      
      // Health check
      healthCheckPath: '/health'
      
      // App Settings
      appSettings: [
        // Application Insights
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
        // .NET Configuration
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Development'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        // Key Vault reference para SQL Connection String
        {
          name: 'ConnectionStrings__DefaultConnection'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=sql-connection-string)'
        }
      ]
      
      // Connection Strings (alternativa a App Settings para DB)
      connectionStrings: []
      
      // CORS (configurar según necesidades)
      cors: {
        allowedOrigins: [
          'https://portal.azure.com' // Solo Azure Portal en dev
        ]
        supportCredentials: false
      }
      
      // IP restrictions (vacío = permitir todo, configurar en prod)
      ipSecurityRestrictions: [
        {
          action: 'Allow'
          name: 'Allow all'
          priority: 100
          ipAddress: 'Any'
        }
      ]
    }
  }
  
  dependsOn: [
    appServicePlan
  ]
}

// ============================================================================
// Key Vault - Almacenar SQL Connection String
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'sql-connection-string'
  properties: {
    value: sqlConnectionString
    contentType: 'text/plain'
  }
}

resource appInsightsInstrumentationKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'appinsights-instrumentation-key'
  properties: {
    value: applicationInsightsInstrumentationKey
    contentType: 'text/plain'
  }
}

// ============================================================================
// RBAC: App Service Managed Identity → Key Vault
// ============================================================================

// Key Vault Secrets User role
var keyVaultSecretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appService.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Diagnostic Settings
// ============================================================================

/*
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appService
  name: 'diag-${appService.name}'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
*/

// ============================================================================
// Outputs
// ============================================================================

@description('ID del App Service Plan')
output appServicePlanId string = appServicePlan.id

@description('Nombre del App Service Plan')
output appServicePlanName string = appServicePlan.name

@description('ID del App Service')
output appServiceId string = appService.id

@description('Nombre del App Service')
output appServiceName string = appService.name

@description('Default hostname del App Service')
output appServiceDefaultHostname string = appService.properties.defaultHostName

@description('URL del App Service')
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'

@description('Principal ID de la Managed Identity del App Service')
output appServicePrincipalId string = appService.identity.principalId

@description('Tenant ID de la Managed Identity')
output appServiceTenantId string = appService.identity.tenantId
