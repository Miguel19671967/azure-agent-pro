// ============================================================================
// Private Endpoint Module - Generic Reusable
// ============================================================================

@description('Name of the private endpoint')
param privateEndpointName string

@description('Location for the private endpoint')
param location string

@description('Resource ID of the private link service')
param privateLinkServiceId string

@description('Group ID of the private link service (e.g., sqlServer, vault, sites)')
param groupId string

@description('Subnet ID where the private endpoint will be deployed')
param subnetId string

@description('Private DNS Zone ID for DNS integration')
param privateDnsZoneId string = ''

@description('Resource tags')
param tags object = {}

// ============================================================================
// PRIVATE ENDPOINT
// ============================================================================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: [
            groupId
          ]
        }
      }
    ]
  }
}

// ============================================================================
// PRIVATE DNS ZONE GROUP (if DNS Zone provided)
// ============================================================================

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = if (!empty(privateDnsZoneId)) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Private Endpoint ID')
output privateEndpointId string = privateEndpoint.id

@description('Private Endpoint Name')
output privateEndpointName string = privateEndpoint.name

@description('Private IP Address')
output privateIpAddress string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
