// ============================================================================
// RBAC Assignments Module
// Configures role assignments for Managed Identities
// ============================================================================

@description('Principal ID of the App Service Managed Identity')
param appServicePrincipalId string

@description('Key Vault name for secrets access')
param keyVaultName string

@description('SQL Server name for database access')
param sqlServerName string

// ============================================================================
// EXISTING RESOURCES
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource sqlServer 'Microsoft.Sql/servers@2023-02-01-preview' existing = {
  name: sqlServerName
}

// ============================================================================
// ROLE DEFINITIONS (Built-in Azure roles)
// ============================================================================

// Key Vault Secrets User - Read secrets
var keyVaultSecretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

// SQL DB Contributor - Manage SQL databases
var sqlDbContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec')

// ============================================================================
// RBAC ASSIGNMENTS
// ============================================================================

// App Service Managed Identity → Key Vault Secrets User
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appServicePrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
    description: 'Allows App Service to read secrets from Key Vault using Managed Identity'
  }
}

// App Service Managed Identity → SQL DB Contributor
resource sqlServerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sqlServer.id, appServicePrincipalId, sqlDbContributorRoleId)
  scope: sqlServer
  properties: {
    roleDefinitionId: sqlDbContributorRoleId
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
    description: 'Allows App Service to manage SQL databases using Managed Identity'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Key Vault RBAC assignment ID')
output keyVaultRoleAssignmentId string = keyVaultRoleAssignment.id

@description('SQL Server RBAC assignment ID')
output sqlServerRoleAssignmentId string = sqlServerRoleAssignment.id

@description('RBAC Configuration Summary')
output rbacSummary object = {
  appServicePrincipalId: appServicePrincipalId
  keyVaultAccess: 'Secrets User (Read)'
  sqlServerAccess: 'DB Contributor (Manage)'
  keyVaultName: keyVaultName
  sqlServerName: sqlServerName
}
