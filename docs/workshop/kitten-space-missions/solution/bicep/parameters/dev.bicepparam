// ============================================================================
// PARAMETERS - Development Environment
// Kitten Space Missions API
// ============================================================================

using '../main.bicep'

// ============================================================================
// PROJECT CONFIGURATION
// ============================================================================

param projectName = 'kitten-missions'
param environment = 'dev'
param location = 'northeurope' // Changed from westeurope due to SQL provisioning restrictions

// ============================================================================
// TAGS
// ============================================================================

param tags = {
  Project: 'Kitten Space Missions'
  Environment: 'dev'
  CostCenter: 'Engineering'
  Owner: 'ionela.morar'
  ManagedBy: 'Bicep-IaC'
  DeployedBy: 'GitHub-Actions'
  Criticality: 'Low'
  AutoShutdown: 'Enabled'
  DataClassification: 'Internal'
}

// ============================================================================
// NETWORKING
// ============================================================================

param vnetAddressPrefix = '10.0.0.0/16'
param appSubnetPrefix = '10.0.1.0/24'
param privateEndpointSubnetPrefix = '10.0.2.0/24'

// ============================================================================
// SQL DATABASE
// ============================================================================

param sqlDatabaseSku = {
  name: 'Basic'
  tier: 'Basic'
  capacity: 5 // 5 DTU
}

param sqlMaxSizeBytes = 2147483648 // 2GB

// ⚠️ IMPORTANTE: Reemplazar con tu Object ID de Azure AD
// Obtener con: az ad signed-in-user show --query id -o tsv
param sqlAadAdminObjectId = 'b6841499-9491-4df2-99e6-b75c1040e4ee' // Reemplazar

// Obtener con: az ad signed-in-user show --query userPrincipalName -o tsv
param sqlAadAdminLogin = 'm.vallemonjas_prodware.es#EXT#@prodwaredevops.onmicrosoft.com' // Reemplazar con tu UPN

// ============================================================================
// APP SERVICE
// ============================================================================

param appServiceSku = {
  name: 'B1'
  tier: 'Basic'
  capacity: 1
}

param appServiceOs = 'Linux'
param appServiceRuntime = 'DOTNETCORE|8.0' // o 'NODE|20-lts', 'PYTHON|3.11'

param enableAutoScale = true

// ============================================================================
// KEY VAULT
// ============================================================================

// ⚠️ IMPORTANTE: Reemplazar con tu Object ID
// Array de Object IDs que tendrán acceso de administrador al Key Vault
param keyVaultAdminObjectIds = [
  'b6841499-9491-4df2-99e6-b75c1040e4ee' // Using same Object ID as SQL admin
]

param keyVaultSku = 'standard'

// ============================================================================
// MONITORING
// ============================================================================

param logRetentionInDays = 30

// ============================================================================
// DEPLOYMENT NOTES
// ============================================================================

// ANTES DE DESPLEGAR:
// 1. Reemplazar 'YOUR_OBJECT_ID_HERE' con tu Azure AD Object ID:
//    az ad signed-in-user show --query id -o tsv
//
// 2. Reemplazar 'ionela.morar@...' con tu User Principal Name:
//    az ad signed-in-user show --query userPrincipalName -o tsv
//
// 3. Verificar que estás logueado con la subscription correcta:
//    az account show --query name
//    Debe ser: "Ionela Morar - MPN"
//
// 4. Si no, configurar subscription:
//    az account set --subscription "e507bceb-37fc-4a08-be9b-c2fd25224ec3"

// DESPLEGAR:
// az deployment group create \
//   --resource-group rg-kitten-missions-dev \
//   --template-file main.bicep \
//   --parameters dev.bicepparam

// VALIDAR ANTES:
// az deployment group validate \
//   --resource-group rg-kitten-missions-dev \
//   --template-file main.bicep \
//   --parameters dev.bicepparam

// WHAT-IF:
// az deployment group what-if \
//   --resource-group rg-kitten-missions-dev \
//   --template-file main.bicep \
//   --parameters dev.bicepparam
