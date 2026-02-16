// ============================================================================
// Monitoring Module - Kitten Space Missions
// ============================================================================
// Crea Log Analytics + Application Insights para observability completa
// Configurado para mantenerse en free tier (5GB/mes)
// ============================================================================

@description('Nombre base para los recursos de monitoring')
param name string

@description('Ubicación de Azure para los recursos')
param location string = resourceGroup().location

@description('Tags comunes para todos los recursos')
param tags object = {}

@description('Retención de logs en días')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Application type para Application Insights')
@allowed([
  'web'
  'other'
])
param applicationType string = 'web'

// ============================================================================
// Log Analytics Workspace
// ============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${name}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018' // Pay-as-you-go, 5GB gratis/mes
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// ============================================================================
// Application Insights
// ============================================================================

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${name}'
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics' // Integrado con Log Analytics
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    DisableIpMasking: false // Enmascarar IPs para GDPR compliance
    
    // Sampling configuration (100% en dev, reducir en prod si es necesario)
    SamplingPercentage: 100
    
    // Retención
    RetentionInDays: retentionInDays
  }
}

// ============================================================================
// Alertas Básicas
// ============================================================================

// Alerta: Alta tasa de errores
resource highErrorRateAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-high-error-rate-${name}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when failed request rate exceeds 10%'
    severity: 2 // Warning
    enabled: true
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT5M' // Evaluar cada 5 minutos
    windowSize: 'PT5M' // Ventana de 5 minutos
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FailedRequestsCount'
          metricName: 'requests/failed'
          dimensions: []
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Count' // Must be Count for requests/failed metric
        }
      ]
    }
    autoMitigate: true
  }
}

// Alerta: Alta latencia
resource highLatencyAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-high-latency-${name}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when p95 response time exceeds 500ms'
    severity: 2 // Warning
    enabled: true
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M' // 10 minutos para evitar false positives
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'RequestDuration'
          metricName: 'requests/duration'
          dimensions: []
          operator: 'GreaterThan'
          threshold: 500 // 500ms
          timeAggregation: 'Average'
        }
      ]
    }
    autoMitigate: true
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('ID del Log Analytics Workspace')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('Nombre del Log Analytics Workspace')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('Customer ID del Log Analytics (para configuración de agents)')
output logAnalyticsCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('ID del Application Insights')
output applicationInsightsId string = applicationInsights.id

@description('Nombre del Application Insights')
output applicationInsightsName string = applicationInsights.name

@description('Instrumentation Key del Application Insights')
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey

@description('Connection String del Application Insights')
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
