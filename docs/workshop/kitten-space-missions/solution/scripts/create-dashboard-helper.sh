#!/bin/bash
#######################################
# 🎨 Dashboard Setup Helper
# Proporciona enlaces directos para crear el dashboard en Azure Portal
#######################################

set -euo pipefail

# Colores
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
RESOURCE_GROUP="rg-kitten-missions-dev"
SUBSCRIPTION_ID="e507bceb-37fc-4a08-be9b-c2fd25224ec3"
APP_INSIGHTS_NAME="appi-kitten-dev"
APP_INSIGHTS_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/microsoft.insights/components/${APP_INSIGHTS_NAME}"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🎨 Azure Portal Dashboard - Quick Links               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}📊 STEP 1: Application Insights - Data Sources${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Metrics Explorer (ver métricas predefinidas):"
echo "https://portal.azure.com/#@/resource${APP_INSIGHTS_ID}/metrics"
echo ""
echo "Logs / KQL Query Editor (ejecutar queries custom):"
echo "https://portal.azure.com/#@/resource${APP_INSIGHTS_ID}/logs"
echo ""
echo "Performance Dashboard (análisis de rendimiento):"
echo "https://portal.azure.com/#@/resource${APP_INSIGHTS_ID}/performance"
echo ""
echo "Failures Dashboard (análisis de errores):"
echo "https://portal.azure.com/#@/resource${APP_INSIGHTS_ID}/failures"
echo ""

echo -e "${GREEN}🎨 STEP 2: Crear Dashboard${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Opción A - Crear Dashboard Vacío:"
echo "https://portal.azure.com/#create/Microsoft.Dashboard"
echo ""
echo "Opción B - Ver Dashboards Existentes:"
echo "https://portal.azure.com/#browse/Microsoft.Portal%2Fdashboards"
echo ""

echo -e "${GREEN}📝 STEP 3: Queries KQL para los Tiles${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  Request Rate (Last 24h) - Line Chart:"
echo ""
cat << 'EOF'
requests
| where timestamp > ago(24h)
| summarize RequestCount = count() by bin(timestamp, 5m)
| render timechart
EOF
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "2️⃣  P95 Latency (seconds) - Big Number:"
echo ""
cat << 'EOF'
requests
| where timestamp > ago(1h)
| summarize p95_duration = percentile(duration, 95)
| extend p95_seconds = round(p95_duration / 1000, 2)
| project p95_seconds
EOF
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "3️⃣  Error Rate (%) - Big Number:"
echo ""
cat << 'EOF'
requests
| where timestamp > ago(1h)
| summarize TotalRequests = count(), 
            FailedRequests = countif(success == false)
| extend ErrorRate = round((FailedRequests * 100.0) / TotalRequests, 2)
| project ErrorRate
EOF
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "4️⃣  Availability (%) - Big Number:"
echo ""
cat << 'EOF'
requests
| where timestamp > ago(24h)
| summarize SuccessfulRequests = countif(success == true), 
            TotalRequests = count()
| extend AvailabilityPercent = round((SuccessfulRequests * 100.0) / TotalRequests, 2)
| project AvailabilityPercent
EOF
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "5️⃣  Recent Failed Requests - Table:"
echo ""
cat << 'EOF'
requests
| where timestamp > ago(1h) and success == false
| project timestamp, name, resultCode, duration, url
| order by timestamp desc
| take 20
EOF
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "6️⃣  Dependency Performance - Bar Chart:"
echo ""
cat << 'EOF'
dependencies
| where timestamp > ago(1h)
| summarize 
    count = count(), 
    avg_duration = avg(duration), 
    p95_duration = percentile(duration, 95) 
by name, type
| extend avg_ms = round(avg_duration, 0)
| order by avg_duration desc
| take 10
| project name, type, count, avg_ms, p95_duration
EOF
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${YELLOW}⚠️  NOTA IMPORTANTE${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Si ves 'No data available' en algún tile:"
echo "1. La aplicación debe estar desplegada y recibiendo tráfico"
echo "2. Genera tráfico de prueba:"
echo "   curl https://app-km-puhqveemr77k.azurewebsites.net"
echo "3. Espera 2-3 minutos para que Application Insights procese los datos"
echo "4. Refresca el dashboard"
echo ""

echo -e "${GREEN}📚 STEP 4: Documentación Completa${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Lee la guía completa en:"
echo "docs/workshop/kitten-space-missions/solution/docs/DASHBOARD_SETUP_GUIDE.md"
echo ""
echo "Incluye:"
echo "  • Pasos detallados con screenshots"
echo "  • Método alternativo con Azure CLI"
echo "  • Template JSON del dashboard"
echo "  • Troubleshooting común"
echo ""

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ✅ Links generados - ¡Abre en tu navegador!           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Tiempo estimado: 15-20 minutos para crear el dashboard completo"
echo ""
