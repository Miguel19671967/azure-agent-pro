// ============================================================================
// Virtual Network Module - Kitten Space Missions
// ============================================================================
// Crea VNet con 2 subnets (App Service + Private Endpoints) y NSG
// Seguridad: Service Endpoints habilitados, NSG rules restrictivas
// ============================================================================

@description('Nombre base para los recursos de networking')
param name string

@description('Ubicación de Azure para los recursos')
param location string = resourceGroup().location

@description('Tags comunes para todos los recursos')
param tags object = {}

@description('Address space de la VNet (CIDR)')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix para subnet de App Service')
param appSubnetPrefix string = '10.0.1.0/24'

@description('Address prefix para subnet de Private Endpoints')
param privateEndpointSubnetPrefix string = '10.0.2.0/24'

// ============================================================================
// Network Security Group (NSG)
// ============================================================================

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-${name}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // ========== INBOUND RULES ==========
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          description: 'Allow HTTPS traffic from Internet to App Service'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: appSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          description: 'Allow HTTP traffic (redirect to HTTPS)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: appSubnetPrefix
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-AppService-to-SQL'
        properties: {
          description: 'Allow App Service to SQL via Private Endpoint'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: privateEndpointSubnetPrefix
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      // ========== OUTBOUND RULES ==========
      {
        name: 'Allow-SQL-Outbound'
        properties: {
          description: 'Allow outbound to SQL Database'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: 'Sql'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-KeyVault-Outbound'
        properties: {
          description: 'Allow outbound to Key Vault'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-Monitor-Outbound'
        properties: {
          description: 'Allow outbound to Azure Monitor / Application Insights'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-Internet-Outbound'
        properties: {
          description: 'Allow outbound to Internet (for external APIs, NuGet, etc.)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
    ]
  }
}

// ============================================================================
// Virtual Network
// ============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${name}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      // Subnet para App Service (VNet Integration)
      {
        name: 'snet-app'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Sql'
              locations: [
                location
              ]
            }
            {
              service: 'Microsoft.KeyVault'
              locations: [
                location
              ]
            }
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      // Subnet para Private Endpoints
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('ID del recurso de la VNet')
output vnetId string = vnet.id

@description('Nombre de la VNet')
output vnetName string = vnet.name

@description('ID de la subnet de App Service')
output appSubnetId string = vnet.properties.subnets[0].id

@description('Nombre de la subnet de App Service')
output appSubnetName string = vnet.properties.subnets[0].name

@description('ID de la subnet de Private Endpoints')
output privateEndpointSubnetId string = vnet.properties.subnets[1].id

@description('Nombre de la subnet de Private Endpoints')
output privateEndpointSubnetName string = vnet.properties.subnets[1].name

@description('ID del NSG')
output nsgId string = nsg.id

@description('Nombre del NSG')
output nsgName string = nsg.name
