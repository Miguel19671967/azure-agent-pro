// ============================================================================
// Azure AI Foundry (AI Services) Deployment
// Cliente: IP Editorial (Ideas Propias Editorial)
// Proyecto: Power Platform RPA + Azure OpenAI Integration
// Tenant Destino: FEMXA Formación S.L.
// ============================================================================

@description('Nombre del recurso Azure AI Services')
param aiServicesName string

@description('Región de Azure para el despliegue')
param location string = 'eastus2'

@description('SKU del servicio (S0 para producción)')
param sku string = 'S0'

@description('Tags para el recurso')
param tags object = {
  Project: 'IPE-RPA'
  Environment: 'Production'
  ManagedBy: 'Bicep-IaC'
  Client: 'IP-Editorial'
  CostCenter: 'RPA-Automation'
}

@description('Habilitar public network access')
param publicNetworkAccess string = 'Enabled' // Cambiar a Disabled para Private Endpoint

// ============================================================================
// Azure AI Services (AI Foundry)
// ============================================================================

resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: aiServicesName
  location: location
  kind: 'AIServices' // Tipo unificado (incluye OpenAI, Speech, Vision, etc.)
  sku: {
    name: sku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: aiServicesName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow' // Cambiar a Deny con Private Endpoints
    }
    disableLocalAuth: false // Permitir API Keys (necesario para Power Platform)
  }
  tags: tags
}

// ============================================================================
// Deployment: GPT-5-nano (Modelo principal para RPA)
// ============================================================================

resource gpt5NanoDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: aiServices
  name: 'gpt-5-nano'
  sku: {
    name: 'GlobalStandard'
    capacity: 1 // Mínimo requerido para GlobalStandard
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5-nano'
      version: '2025-08-07'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
    raiPolicyName: 'Microsoft.Default'
  }
}

// ============================================================================
// Deployment: GPT-5-mini (Opcional - para tareas más complejas)
// ============================================================================

resource gpt5MiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: aiServices
  name: 'gpt-5-mini'
  sku: {
    name: 'GlobalStandard'
    capacity: 1 // Mínimo requerido para GlobalStandard
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5-mini'
      version: '2025-08-07'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
    raiPolicyName: 'Microsoft.Default'
  }
  dependsOn: [
    gpt5NanoDeployment // Desplegar secuencialmente
  ]
}

// ============================================================================
// OUTPUTS (Para usar en Power Platform)
// ============================================================================

@description('ID del recurso AI Services')
output aiServicesId string = aiServices.id

@description('Endpoint del AI Services (para Power Platform connection)')
output aiServicesEndpoint string = aiServices.properties.endpoint

@description('Nombre del recurso')
output aiServicesName string = aiServices.name

@description('API Key (Primary) - Almacenar en Key Vault')
output aiServicesKey string = aiServices.listKeys().key1

@description('Deployment name GPT-5-nano')
output gpt5NanoDeploymentName string = gpt5NanoDeployment.name

@description('Deployment name GPT-5-mini')
output gpt5MiniDeploymentName string = gpt5MiniDeployment.name

@description('Región del despliegue')
output location string = location

// ============================================================================
// NOTAS DE USO:
// ============================================================================
// 1. El endpoint será: https://<aiServicesName>.cognitiveservices.azure.com/
// 2. API Key se obtiene con: az cognitiveservices account keys list
// 3. Para Power Platform Connection:
//    - Endpoint: <output aiServicesEndpoint>
//    - API Key: <output aiServicesKey> (almacenar en Key Vault)
//    - Deployment: gpt-5-nano (o gpt-5-mini según uso)
// ============================================================================
