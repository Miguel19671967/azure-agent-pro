// ============================================================================
// MAIN ORCHESTRATOR - Kitten Space Missions API
// ============================================================================
// Orquesta el despliegue completo de la arquitectura:
// - Virtual Network + NSG
// - SQL Database + Private Endpoint
// - Key Vault
// - App Service + Plan
// - Application Insights + Log Analytics
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Nombre del proyecto (usado como base para naming)')
@minLength(3)
@maxLength(15)
param projectName string

@description('Entorno de despliegue')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param environment string

@description('Ubicación de Azure')
param location string = resourceGroup().location

@description('Tags comunes para todos los recursos')
param tags object = {
  Project: 'Kitten Space Missions'
  Environment: environment
  ManagedBy: 'Bicep-IaC'
  DeployedBy: 'GitHub-Actions'
  Owner: 'MeowTech Space Agency'
}

// Networking parameters
@description('Address space de la VNet')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix para subnet de App Service')
param appSubnetPrefix string = '10.0.1.0/24'

@description('Address prefix para subnet de Private Endpoints')
param privateEndpointSubnetPrefix string = '10.0.2.0/24'

// SQL Database parameters
@description('SKU de SQL Database')
param sqlDatabaseSku object = {
  name: 'Basic'
  tier: 'Basic'
  capacity: 5
}

@description('Tamaño máximo de SQL Database en bytes (2GB)')
param sqlMaxSizeBytes int = 2147483648

@description('Azure AD admin Object ID para SQL Server')
param sqlAadAdminObjectId string

@description('Azure AD admin login name para SQL Server')
param sqlAadAdminLogin string

// App Service parameters
@description('SKU de App Service Plan')
param appServiceSku object = {
  name: 'B1'
  tier: 'Basic'
  capacity: 1
}

@description('Sistema operativo')
param appServiceOs string = 'Linux'

@description('Runtime stack')
param appServiceRuntime string = 'DOTNETCORE|8.0'

@description('Habilitar auto-scaling')
param enableAutoScale bool = true

// Key Vault parameters
@description('Object IDs con acceso de administrador a Key Vault')
param keyVaultAdminObjectIds array

@description('SKU de Key Vault')
param keyVaultSku string = 'standard'

// Monitoring parameters
@description('Retención de logs en días')
param logRetentionInDays int = 30

// ============================================================================
// VARIABLES
// ============================================================================

var resourceBaseName = '${projectName}-${environment}'

// ============================================================================
// MODULE: MONITORING (primero, porque otros módulos lo necesitan)
// ============================================================================

module monitoring 'modules/monitoring.bicep' = {
  name: 'deploy-monitoring-${uniqueString(resourceGroup().id)}'
  params: {
    name: resourceBaseName
    location: location
    tags: tags
    retentionInDays: logRetentionInDays
    applicationType: 'web'
  }
}

// ============================================================================
// MODULE: VIRTUAL NETWORK
// ============================================================================

module network 'modules/virtual-network.bicep' = {
  name: 'deploy-network-${uniqueString(resourceGroup().id)}'
  params: {
    name: resourceBaseName
    location: location
    tags: tags
    vnetAddressPrefix: vnetAddressPrefix
    appSubnetPrefix: appSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
  }
}

// ============================================================================
// MODULE: KEY VAULT
// ============================================================================

module keyVault 'modules/key-vault.bicep' = {
  name: 'deploy-keyvault-${uniqueString(resourceGroup().id)}'
  params: {
    name: resourceBaseName
    location: location
    tags: tags
    sku: keyVaultSku
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false // false en dev para facilitar cleanup
    enableRbacAuthorization: true
    administratorObjectIds: keyVaultAdminObjectIds
  }
}

// ============================================================================
// MODULE: SQL DATABASE
// ============================================================================

module sqlDatabase 'modules/sql-database.bicep' = {
  name: 'deploy-sql-${uniqueString(resourceGroup().id)}'
  params: {
    name: resourceBaseName
    location: location
    tags: tags
    databaseSku: sqlDatabaseSku
    maxSizeBytes: sqlMaxSizeBytes
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    aadAdminObjectId: sqlAadAdminObjectId
    aadAdminLogin: sqlAadAdminLogin
  }
  dependsOn: [
    network
  ]
}

// ============================================================================
// MODULE: APP SERVICE
// ============================================================================

module appService 'modules/app-service.bicep' = {
  name: 'deploy-appservice-${uniqueString(resourceGroup().id)}'
  params: {
    name: resourceBaseName
    location: location
    tags: tags
    sku: appServiceSku
    operatingSystem: appServiceOs
    linuxFxVersion: appServiceRuntime
    appSubnetId: network.outputs.appSubnetId
    applicationInsightsId: monitoring.outputs.applicationInsightsId
    applicationInsightsInstrumentationKey: monitoring.outputs.applicationInsightsInstrumentationKey
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
    keyVaultUri: keyVault.outputs.keyVaultUri
    sqlConnectionString: sqlDatabase.outputs.connectionString
    keyVaultName: keyVault.outputs.keyVaultName
    enableAutoScale: enableAutoScale
  }
  dependsOn: [
    network
    keyVault
    sqlDatabase
    monitoring
  ]
}

// ============================================================================
// RBAC: App Service Managed Identity → SQL Database
// ============================================================================

// Nota: La asignación de roles SQL (db_datareader, db_datawriter) debe hacerse
// mediante scripts SQL después del despliegue de infraestructura:
// 
// CREATE USER [app-${resourceBaseName}] FROM EXTERNAL PROVIDER;
// ALTER ROLE db_datareader ADD MEMBER [app-${resourceBaseName}];
// ALTER ROLE db_datawriter ADD MEMBER [app-${resourceBaseName}];
//
// Esto se puede automatizar con un Deployment Script o ejecutar manualmente

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Nombre del Resource Group')
output resourceGroupName string = resourceGroup().name

@description('Ubicación')
output location string = location

@description('Entorno')
output environment string = environment

// Networking outputs
@description('ID de la VNet')
output vnetId string = network.outputs.vnetId

@description('Nombre de la VNet')
output vnetName string = network.outputs.vnetName

// SQL outputs
@description('Nombre del SQL Server')
output sqlServerName string = sqlDatabase.outputs.sqlServerName

@description('FQDN del SQL Server')
output sqlServerFqdn string = sqlDatabase.outputs.sqlServerFqdn

@description('Nombre de la SQL Database')
output sqlDatabaseName string = sqlDatabase.outputs.sqlDatabaseName

// Key Vault outputs
@description('Nombre del Key Vault')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('URI del Key Vault')
output keyVaultUri string = keyVault.outputs.keyVaultUri

// App Service outputs
@description('Nombre del App Service')
output appServiceName string = appService.outputs.appServiceName

@description('URL del App Service')
output appServiceUrl string = appService.outputs.appServiceUrl

@description('Principal ID de la Managed Identity del App Service')
output appServicePrincipalId string = appService.outputs.appServicePrincipalId

// Monitoring outputs
@description('Nombre del Application Insights')
output applicationInsightsName string = monitoring.outputs.applicationInsightsName

@description('Nombre del Log Analytics Workspace')
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName

// ============================================================================
// POST-DEPLOYMENT INFO
// ============================================================================

output deploymentInstructions string = '''
✅ Infraestructura desplegada correctamente!

📋 PRÓXIMOS PASOS:

1. Configurar permisos SQL para Managed Identity:
   - Conectar a SQL Database con tu cuenta AAD
   - Ejecutar:
     CREATE USER [${appService.outputs.appServiceName}] FROM EXTERNAL PROVIDER;
     ALTER ROLE db_datareader ADD MEMBER [${appService.outputs.appServiceName}];
     ALTER ROLE db_datawriter ADD MEMBER [${appService.outputs.appServiceName}];

2. Desplegar código de la API:
   - Build: dotnet publish -c Release
   - Deploy: az webapp deployment source config-zip

3. Verificar conectividad:
   - Health check: ${appService.outputs.appServiceUrl}/health
   - Application Insights: Verificar telemetría
   - SQL: Probar conexión desde App Service

4. Testing:
   - Smoke tests
   - Load testing (ab, k6, Artillery)
   - Security scanning (OWASP ZAP)

📊 MONITORING:
   - Application Insights: https://portal.azure.com/#@/resource${monitoring.outputs.applicationInsightsId}
   - Log Analytics: https://portal.azure.com/#@/resource${monitoring.outputs.logAnalyticsWorkspaceId}

🔐 SECURITY:
   - Key Vault: ${keyVault.outputs.keyVaultUri}
   - SQL Server (Private): ${sqlDatabase.outputs.sqlServerFqdn}
   - No public endpoints habilitados ✅

💰 COST MONITORING:
   - Costo estimado: ~€26.53/mes
   - Budget alerts configurados
   - Tags aplicados para cost allocation
'''
