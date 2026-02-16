// ============================================================================
// SQL Database Module - Kitten Space Missions
// ============================================================================
// Crea SQL Server + Database con Private Endpoint
// Seguridad: AAD-only auth, public access disabled, backup automático
// ============================================================================

@description('Nombre base para los recursos de SQL')
param name string

@description('Ubicación de Azure para los recursos')
param location string = resourceGroup().location

@description('Tags comunes para todos los recursos')
param tags object = {}

@description('Administrator login para SQL Server (AAD only, este parámetro es requerido pero no se usa)')
param administratorLogin string = 'sqladmin'

@description('SKU de la base de datos')
param databaseSku object = {
  name: 'Basic'
  tier: 'Basic'
  capacity: 5
}

@description('Tamaño máximo de la base de datos en bytes (2GB por defecto)')
param maxSizeBytes int = 2147483648

@description('ID de la subnet para Private Endpoint')
param privateEndpointSubnetId string

@description('ID del Azure AD admin (Object ID del usuario o grupo)')
param aadAdminObjectId string

@description('Login name del Azure AD admin')
param aadAdminLogin string

@description('Tenant ID')
param tenantId string = tenant().tenantId

// ============================================================================
// SQL Server (logical server)
// ============================================================================

// SQL Server names must be globally unique
// Max 63 chars: sql-km-dev-xxxxxxxxxxxx (24 chars)
var sqlServerName = 'sql-km-${substring(uniqueString(resourceGroup().id), 0, 12)}'

resource sqlServer 'Microsoft.Sql/servers@2023-02-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    // AAD-only authentication
    administratorLogin: administratorLogin // Requerido pero no usado con AAD-only
    administratorLoginPassword: guid(resourceGroup().id, sqlServerName) // Password random, no usado
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled' // Sin acceso público
    restrictOutboundNetworkAccess: 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User' // o 'Group'
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: tenantId
      azureADOnlyAuthentication: true // Solo AAD auth
    }
  }
}

// ============================================================================
// SQL Database
// ============================================================================

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-02-01-preview' = {
  parent: sqlServer
  name: 'sqldb-${name}'
  location: location
  tags: tags
  sku: databaseSku
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: maxSizeBytes
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false // Dev no necesita zone redundancy
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local' // LRS backup (más barato para dev)
    isLedgerOn: false
  }
}

// Configuración de backup (automático)
resource backupShortTermRetentionPolicy 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2023-02-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    retentionDays: 7 // 7 días de retención (incluido en precio Basic)
    diffBackupIntervalInHours: 24
  }
}

// Transparent Data Encryption (TDE) viene habilitado automáticamente en Azure SQL Database
// No es necesario configurarlo explícitamente para service-managed keys

// ============================================================================
// Private DNS Zone para SQL
// ============================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: tags
}

// Obtener VNet ID desde el subnet ID
var vnetId = substring(privateEndpointSubnetId, 0, lastIndexOf(privateEndpointSubnetId, '/subnets/'))

// Link DNS Zone a VNet
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-${name}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ============================================================================
// Private Endpoint para SQL Server
// ============================================================================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-sql-${name}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-connection-sql-${name}'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

// DNS Zone Group (asocia Private Endpoint con Private DNS Zone)
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ============================================================================
// Diagnostic Settings para auditoría
// ============================================================================

// Nota: Requiere Log Analytics workspace ID como parámetro si se habilita
// Por ahora comentado, se puede habilitar pasando workspaceId

/*
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlDatabase
  name: 'diag-${name}'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLInsights'
        enabled: true
      }
      {
        category: 'AutomaticTuning'
        enabled: true
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: true
      }
      {
        category: 'Errors'
        enabled: true
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: true
      }
      {
        category: 'Timeouts'
        enabled: true
      }
      {
        category: 'Blocks'
        enabled: true
      }
      {
        category: 'Deadlocks'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
      }
      {
        category: 'InstanceAndAppAdvanced'
        enabled: true
      }
      {
        category: 'WorkloadManagement'
        enabled: true
      }
    ]
  }
}
*/

// ============================================================================
// Outputs
// ============================================================================

@description('ID del SQL Server')
output sqlServerId string = sqlServer.id

@description('Nombre del SQL Server')
output sqlServerName string = sqlServer.name

@description('FQDN del SQL Server')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('ID de la SQL Database')
output sqlDatabaseId string = sqlDatabase.id

@description('Nombre de la SQL Database')
output sqlDatabaseName string = sqlDatabase.name

@description('ID del Private Endpoint')
output privateEndpointId string = privateEndpoint.id

@description('Nombre del Private Endpoint')
output privateEndpointName string = privateEndpoint.name

@description('Connection String (con AAD authentication)')
output connectionString string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${sqlDatabase.name};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
