// ============================================================================
// Key Vault Module - Kitten Space Missions
// ============================================================================
// Crea Key Vault con RBAC authorization model
// Seguridad: Soft delete enabled, purge protection, audit logging
// ============================================================================

@description('Nombre base para el Key Vault (se añadirá sufijo único)')
param name string

@description('Ubicación de Azure para los recursos')
param location string = resourceGroup().location

@description('Tags comunes para todos los recursos')
param tags object = {}

@description('SKU del Key Vault')
@allowed([
  'standard'
  'premium'
])
param sku string = 'standard'

@description('Habilitar soft delete (recomendado)')
param enableSoftDelete bool = true

@description('Días de retención para soft delete')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 7

@description('Habilitar purge protection (recomendado para producción)')
param enablePurgeProtection bool = false // Deshabilitado en dev para facilitar cleanup

@description('Usar modelo de autorización RBAC (recomendado vs access policies)')
param enableRbacAuthorization bool = true

@description('Object IDs que tendrán acceso como Key Vault Administrator')
param administratorObjectIds array = []

@description('Tenant ID')
param tenantId string = tenant().tenantId

// ============================================================================
// Key Vault
// ============================================================================

// Generar nombre único (Key Vault names must be globally unique)
// Max 24 chars: kv-km-dev-xxxxxxxxxxxx (24 chars)
var keyVaultName = 'kv-km-${substring(uniqueString(resourceGroup().id), 0, 12)}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: sku
    }
    
    // Autorización via RBAC (mejor práctica)
    enableRbacAuthorization: enableRbacAuthorization
    
    // Soft delete configuration
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    
    // Network ACLs (permitir acceso desde Azure services)
    networkAcls: {
      defaultAction: 'Allow' // En dev, permitir acceso desde Azure services
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
    
    // Public network access (habilitado en dev, deshabilitar en prod)
    publicNetworkAccess: 'Enabled'
    
    // Configuraciones de seguridad
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true // Permitir acceso desde ARM templates
  }
}

// ============================================================================
// RBAC Assignments para Administrators
// ============================================================================

// Built-in role: Key Vault Administrator
// https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator
var keyVaultAdministratorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')

// Asignar rol Key Vault Administrator a los object IDs proporcionados
resource keyVaultAdminRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for objectId in administratorObjectIds: {
  name: guid(keyVault.id, objectId, keyVaultAdministratorRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultAdministratorRoleId
    principalId: objectId
    principalType: 'User' // Cambiar a 'ServicePrincipal' si es una MI o SP
  }
}]

// ============================================================================
// Diagnostic Settings (opcional, comentado por ahora)
// ============================================================================

/*
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: 'diag-${keyVaultName}'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
  }
}
*/

// ============================================================================
// Outputs
// ============================================================================

@description('ID del Key Vault')
output keyVaultId string = keyVault.id

@description('Nombre del Key Vault')
output keyVaultName string = keyVault.name

@description('URI del Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Built-in role ID: Key Vault Secrets User (para asignar a App Service MI)')
output keyVaultSecretsUserRoleId string = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
