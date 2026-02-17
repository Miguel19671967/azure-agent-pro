# 📊 Guía Paso a Paso: Crear Dashboard en Azure Portal

## Kitten Space Missions - Dashboard de Monitorización

Esta guía te llevará paso a paso para crear el dashboard de monitorización en **Azure Portal**.

---

## 🎯 Objetivo

Crear un dashboard operacional con:
- Request rate (líneas de tiempo)
- Latency P95 (gauge)
- Error rate (big number)
- Availability (percentage)
- Failed requests (tabla)
- Dependency performance (bar chart)

---

## 📋 Método 1: Creación Manual en Azure Portal (Recomendado)

### Paso 1: Acceder a Azure Portal

1. Abre tu navegador web
2. Ve a: **https://portal.azure.com**
3. Inicia sesión con tu cuenta: `m.vallemonjas@prodware.es`
4. Verifica que estés en el tenant correcto (Prodware)

### Paso 2: Navegar a Application Insights

1. En la barra de búsqueda superior, escribe: **Application Insights**
2. Click en "Application Insights" en los resultados
3. Selecciona tu recurso: **appi-kitten-dev**
4. Deberías ver el overview de Application Insights

### Paso 3: Crear Nuevo Dashboard

**Opción A: Desde el botón Dashboard del Portal**

1. En la barra lateral izquierda del portal, click en **"Dashboard"** (icono de cuadrados)
2. Click en **"+ Create"** → **"Custom"**
3. Nombre del dashboard: **"Kitten Missions - Dev"**
4. Click en **"Create"**

**Opción B: Desde Application Insights**

1. Estando en Application Insights (`appi-kitten-dev`)
2. Click en el icono **"Pin to dashboard"** (📌) en cualquier gráfico
3. Selecciona **"Create new"** → **"Public dashboard"**
4. Nombre: **"Kitten Missions - Dev"**

### Paso 4: Añadir Tile - Request Rate (Overview)

1. En el dashboard vacío, click en **"+ Add"** → **"Tile gallery"**
2. Selecciona **"Metrics chart"**
3. Click en **"Add"**
4. Configura el tile:
   - **Resource**: selecciona `appi-kitten-dev`
   - **Metric Namespace**: Application Insights standard metrics
   - **Metric**: `Server requests`
   - **Aggregation**: `Count`
   - **Time range**: Last 24 hours
   - **Chart type**: Line chart
5. Click en **"Apply"**
6. Arrastra el tile al tamaño deseado (grande, arriba izquierda)

**Alternativa usando Logs (KQL Query)**:

1. En lugar de "Metrics chart", selecciona **"Logs"**
2. En el editor, pega esta query:
   ```kql
   requests
   | where timestamp > ago(24h)
   | summarize RequestCount = count() by bin(timestamp, 5m)
   | render timechart 
   ```
3. Click en **"Run"**
4. Click en **"Pin to dashboard"** → selecciona tu dashboard
5. Título: **"Request Rate (Last 24h)"**

### Paso 5: Añadir Tile - Latency P95 Gauge

1. Click en **"+ Add"** → **"Tile gallery"** → **"Logs"**
2. Pega esta query:
   ```kql
   requests
   | where timestamp > ago(1h)
   | summarize p95_duration = percentile(duration, 95)
   | extend p95_seconds = p95_duration / 1000
   | project p95_seconds
   ```
3. Click en **"Run"**
4. En el resultado, verás un número (ej: 0.15 segundos)
5. Click en **"Chart"** → Selecciona **"Stat"** (big number)
6. Click en **"Pin to dashboard"**
7. Título: **"P95 Latency (seconds)"**
8. Posición: arriba, centro

### Paso 6: Añadir Tile - Error Rate

1. Click en **"+ Add"** → **"Logs"**
2. Pega esta query:
   ```kql
   requests
   | where timestamp > ago(1h)
   | summarize TotalRequests = count(), 
               FailedRequests = countif(success == false)
   | extend ErrorRate = round((FailedRequests * 100.0) / TotalRequests, 2)
   | project ErrorRate
   ```
3. Click en **"Run"**
4. Cambia visualización a **"Stat"** (big number)
5. Click en **"Pin to dashboard"**
6. Título: **"Error Rate (%)"**
7. Posición: arriba, derecha

### Paso 7: Añadir Tile - Availability Percentage

1. Click en **"+ Add"** → **"Logs"**
2. Pega esta query:
   ```kql
   requests
   | where timestamp > ago(24h)
   | summarize SuccessfulRequests = countif(success == true), TotalRequests = count()
   | extend AvailabilityPercent = round((SuccessfulRequests * 100.0) / TotalRequests, 2)
   | project AvailabilityPercent
   ```
3. Click en **"Run"**
4. Cambia visualización a **"Stat"**
5. Click en **"Pin to dashboard"**
6. Título: **"Availability (%)"**
7. Posición: segunda fila, izquierda

### Paso 8: Añadir Tile - Failed Requests Table

1. Click en **"+ Add"** → **"Logs"**
2. Pega esta query:
   ```kql
   requests
   | where timestamp > ago(1h) and success == false
   | project timestamp, name, resultCode, duration, url
   | order by timestamp desc
   | take 20
   ```
3. Click en **"Run"**
4. Visualización será automáticamente **"Table"**
5. Click en **"Pin to dashboard"**
6. Título: **"Recent Failed Requests"**
7. Posición: tercera fila, full width

### Paso 9: Añadir Tile - Dependency Performance

1. Click en **"+ Add"** → **"Logs"**
2. Pega esta query:
   ```kql
   dependencies
   | where timestamp > ago(1h)
   | summarize 
       count = count(), 
       avg_duration = avg(duration), 
       p95_duration = percentile(duration, 95) 
   by name, type
   | order by avg_duration desc
   | take 10
   ```
3. Click en **"Run"**
4. Cambia visualización a **"Bar chart"**
5. Click en **"Pin to dashboard"**
6. Título: **"Dependency Performance (Avg Duration)"**
7. Posición: segunda fila, derecha

### Paso 10: Guardar Dashboard

1. Una vez que tengas todos los tiles configurados
2. Click en **"Done editing"** (arriba derecha)
3. Tu dashboard se guardará automáticamente
4. Puedes volver a él desde **"Dashboard"** en la barra lateral

---

## 📋 Método 2: Importar Dashboard desde JSON (Avanzado)

Si prefieres automatizar, puedes usar un template ARM/JSON. Aquí te muestro cómo:

### Paso 1: Crear el JSON del Dashboard

Guarda este contenido en `/tmp/dashboard-kitten.json`:

```json
{
  "properties": {
    "lenses": {
      "0": {
        "order": 0,
        "parts": {
          "0": {
            "position": {
              "x": 0,
              "y": 0,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": "/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev"
                },
                {
                  "name": "Query",
                  "value": "requests\n| where timestamp > ago(24h)\n| summarize RequestCount = count() by bin(timestamp, 5m)\n| render timechart"
                },
                {
                  "name": "TimeRange",
                  "value": "PT24H"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AnalyticsLineChartPart",
              "settings": {
                "content": {
                  "PartTitle": "Request Rate (Last 24h)",
                  "PartSubTitle": "Kitten Space Missions"
                }
              }
            }
          },
          "1": {
            "position": {
              "x": 6,
              "y": 0,
              "colSpan": 3,
              "rowSpan": 2
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": "/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev"
                },
                {
                  "name": "Query",
                  "value": "requests\n| where timestamp > ago(1h)\n| summarize p95_duration = percentile(duration, 95)\n| extend p95_seconds = p95_duration / 1000\n| project p95_seconds"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AnalyticsPart",
              "settings": {
                "content": {
                  "PartTitle": "P95 Latency (seconds)"
                }
              }
            }
          },
          "2": {
            "position": {
              "x": 9,
              "y": 0,
              "colSpan": 3,
              "rowSpan": 2
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": "/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev"
                },
                {
                  "name": "Query",
                  "value": "requests\n| where timestamp > ago(1h)\n| summarize TotalRequests = count(), FailedRequests = countif(success == false)\n| extend ErrorRate = round((FailedRequests * 100.0) / TotalRequests, 2)\n| project ErrorRate"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AnalyticsPart",
              "settings": {
                "content": {
                  "PartTitle": "Error Rate (%)"
                }
              }
            }
          },
          "3": {
            "position": {
              "x": 0,
              "y": 4,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": "/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev"
                },
                {
                  "name": "Query",
                  "value": "requests\n| where timestamp > ago(1h) and success == false\n| project timestamp, name, resultCode, duration, url\n| order by timestamp desc\n| take 20"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AnalyticsGridPart",
              "settings": {
                "content": {
                  "PartTitle": "Recent Failed Requests"
                }
              }
            }
          },
          "4": {
            "position": {
              "x": 6,
              "y": 4,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": "/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev"
                },
                {
                  "name": "Query",
                  "value": "dependencies\n| where timestamp > ago(1h)\n| summarize count = count(), avg_duration = avg(duration), p95_duration = percentile(duration, 95) by name, type\n| order by avg_duration desc\n| take 10"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AnalyticsBarChartPart",
              "settings": {
                "content": {
                  "PartTitle": "Dependency Performance"
                }
              }
            }
          }
        }
      }
    },
    "metadata": {
      "model": {
        "timeRange": {
          "value": {
            "relative": {
              "duration": 24,
              "timeUnit": 1
            }
          },
          "type": "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  },
  "name": "Kitten Missions - Dev",
  "type": "Microsoft.Portal/dashboards",
  "location": "global",
  "tags": {
    "hidden-title": "Kitten Missions - Dev Dashboard",
    "Environment": "dev",
    "Project": "KittenSpaceMissions"
  }
}
```

### Paso 2: Crear Dashboard con Azure CLI

```bash
# Variables
RESOURCE_GROUP="rg-kitten-missions-dev"
DASHBOARD_NAME="kitten-missions-dev-dashboard"
DASHBOARD_FILE="/tmp/dashboard-kitten.json"

# Crear dashboard
az portal dashboard create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DASHBOARD_NAME" \
  --input-path "$DASHBOARD_FILE" \
  --location "global"
```

### Paso 3: Verificar Dashboard Creado

```bash
# Listar dashboards
az portal dashboard list \
  --resource-group "$RESOURCE_GROUP" \
  --output table

# Ver detalles
az portal dashboard show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DASHBOARD_NAME"
```

### Paso 4: Acceder al Dashboard en Portal

1. Ve a: https://portal.azure.com
2. Click en **"Dashboard"** en la barra lateral
3. Selecciona **"Kitten Missions - Dev"** del dropdown
4. Deberías ver todos los tiles configurados

---

## 📋 Método 3: Script Bash Automatizado

También he creado un script que puedes ejecutar:

```bash
#!/bin/bash
# scripts/create-dashboard.sh

set -euo pipefail

RESOURCE_GROUP="rg-kitten-missions-dev"
APP_INSIGHTS_ID="/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev"

echo "🎨 Creando dashboard en Azure Portal..."

# Nota: az portal dashboard create requiere un JSON complejo
# Es más fácil crear el dashboard manualmente en el portal
# Este script proporciona los enlaces directos

echo ""
echo "📊 Dashboard URLs:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Application Insights Metrics:"
echo "   https://portal.azure.com/#@/resource/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev/metrics"
echo ""
echo "2. Application Insights Logs (KQL queries):"
echo "   https://portal.azure.com/#@/resource/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev/logs"
echo ""
echo "3. Crear Dashboard:"
echo "   https://portal.azure.com/#create/Microsoft.Dashboard"
echo ""
echo "4. Ver Dashboards existentes:"
echo "   https://portal.azure.com/#browse/Microsoft.Portal%2Fdashboards"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Sigue los pasos del archivo DASHBOARD_SETUP_GUIDE.md"
echo "   para añadir cada tile con las queries KQL proporcionadas."
echo ""
```

**Ejecutar**:
```bash
chmod +x scripts/create-dashboard.sh
./scripts/create-dashboard.sh
```

---

## 🔗 Accesos Directos (Links)

### Application Insights

**Metrics Explorer**:
```
https://portal.azure.com/#@/resource/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev/metrics
```

**Logs (KQL Query Editor)**:
```
https://portal.azure.com/#@/resource/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev/logs
```

**Performance**:
```
https://portal.azure.com/#@/resource/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev/performance
```

**Failures**:
```
https://portal.azure.com/#@/resource/subscriptions/e507bceb-37fc-4a08-be9b-c2fd25224ec3/resourceGroups/rg-kitten-missions-dev/providers/microsoft.insights/components/appi-kitten-dev/failures
```

### Dashboard Management

**Crear Nuevo Dashboard**:
```
https://portal.azure.com/#create/Microsoft.Dashboard
```

**Ver Todos los Dashboards**:
```
https://portal.azure.com/#browse/Microsoft.Portal%2Fdashboards
```

---

## ✅ Checklist de Validación

Después de crear el dashboard, verifica que tienes:

- [ ] **Request Rate chart** (línea de tiempo, últimas 24h)
- [ ] **P95 Latency** (big number, < 500ms target)
- [ ] **Error Rate** (big number, < 1% target)
- [ ] **Availability** (percentage, > 99.5% target)
- [ ] **Failed Requests** (tabla con detalles)
- [ ] **Dependency Performance** (bar chart, SQL + Key Vault)

- [ ] Dashboard es **público** (visible sin autenticación adicional)
- [ ] Dashboard tiene tags de proyecto (Environment: dev, Project: KittenSpaceMissions)
- [ ] Todas las queries KQL funcionan correctamente
- [ ] Time ranges configurados (24h para overview, 1h para detalles)

---

## 🚨 Troubleshooting

### Error: "No data available"

**Causa**: Application Insights no tiene datos aún (app no desplegada).

**Solución**: 
1. Despliega una aplicación al App Service
2. Genera tráfico de prueba: `curl https://app-km-puhqveemr77k.azurewebsites.net`
3. Espera 2-3 minutos para que los datos aparezcan
4. Refresca el dashboard

### Error: "Query failed"

**Causa**: Sintaxis incorrecta en KQL query.

**Solución**:
1. Ve a Application Insights → Logs
2. Prueba la query manualmente
3. Copia el resultado exitoso
4. Pégalo en el dashboard tile

### Error: "Permission denied"

**Causa**: No tienes permisos de escritura en el Resource Group.

**Solución**:
```bash
# Verificar permisos
az role assignment list \
  --assignee m.vallemonjas@prodware.es \
  --resource-group rg-kitten-missions-dev \
  --output table

# Debería mostrar "Owner" o "Contributor"
```

---

## 📚 Referencias

- [Azure Portal Dashboards Documentation](https://learn.microsoft.com/azure/azure-portal/azure-portal-dashboards)
- [KQL Query Language Reference](https://learn.microsoft.com/azure/data-explorer/kql-quick-reference)
- [Application Insights Data Model](https://learn.microsoft.com/azure/azure-monitor/app/data-model)
- [Visualize log data in Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/visualize/workbooks-overview)

---

## 🎉 ¡Listo!

Una vez completados estos pasos, tendrás un **dashboard operacional completo** para monitorizar tu aplicación Kitten Space Missions en tiempo real.

**Tiempo estimado**: 15-20 minutos (método manual)  
**Tiempo estimado**: 5 minutos (método JSON/CLI, si funciona)

**Próximos pasos**:
1. Generar tráfico de prueba en la aplicación
2. Verificar que los datos se muestran correctamente
3. Configurar refresh automático (cada 5 minutos)
4. Compartir dashboard con el equipo
