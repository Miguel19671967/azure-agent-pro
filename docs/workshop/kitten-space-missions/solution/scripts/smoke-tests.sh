#!/bin/bash
#######################################
# 🧪 Smoke Tests - Kitten Space Missions
# Valida que toda la infraestructura esté desplegada y operativa
#######################################

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Configuración
RESOURCE_GROUP="rg-kitten-missions-dev"
APP_SERVICE_NAME="app-km-puhqveemr77k"
SQL_SERVER_NAME="sql-km-puhqveemr77k"
SQL_DATABASE_NAME="sqldb-kitten-dev"
KEY_VAULT_NAME="kv-km-puhqveemr77k"
VNET_NAME="vnet-kitten-dev"
NSG_NAME="nsg-kitten-dev"
APP_INSIGHTS_NAME="appi-kitten-dev"
LOG_ANALYTICS_NAME="log-kitten-dev"
PRIVATE_ENDPOINT_NAME="pe-sql-kitten-dev"

echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   🧪 Smoke Tests - Kitten Space Missions Workshop     ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Función para test individual
test_resource() {
    local test_name="$1"
    local command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo -n "[$TESTS_TOTAL] Testing: $test_name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 1. RESOURCE GROUP VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_resource "Resource Group exists" \
    "az group show --name $RESOURCE_GROUP --query name"

test_resource "Resource Group location is North Europe" \
    "az group show --name $RESOURCE_GROUP --query location | grep -q northeurope"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 2. APP SERVICE VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_resource "App Service exists" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query name"

test_resource "App Service is Running" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query state | grep -q Running"

test_resource "HTTPS Only is enabled" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query httpsOnly | grep -q true"

test_resource "Managed Identity is configured" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query identity.type | grep -q SystemAssigned"

test_resource "App Service responds to HTTP" \
    "curl -s -o /dev/null -w '%{http_code}' https://${APP_SERVICE_NAME}.azurewebsites.net | grep -q 200"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗄️  3. SQL DATABASE VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_resource "SQL Server exists" \
    "az sql server show --name $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query name"

test_resource "SQL Database exists" \
    "az sql db show --name $SQL_DATABASE_NAME --server $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query name"

test_resource "SQL Database is Online" \
    "az sql db show --name $SQL_DATABASE_NAME --server $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query status | grep -q Online"

test_resource "SQL Database is Basic tier" \
    "az sql db show --name $SQL_DATABASE_NAME --server $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query currentServiceObjectiveName | grep -q Basic"

test_resource "SQL Public Access is Disabled" \
    "az sql server show --name $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query publicNetworkAccess | grep -q Disabled"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 4. KEY VAULT VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_resource "Key Vault exists" \
    "az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query name"

test_resource "Key Vault is accessible" \
    "az keyvault list --resource-group $RESOURCE_GROUP --query \"[?name=='$KEY_VAULT_NAME'].name\" -o tsv | grep -q $KEY_VAULT_NAME"

test_resource "Soft Delete is enabled" \
    "az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query properties.enableSoftDelete | grep -q true"

test_resource "Purge Protection is enabled" \
    "az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query properties.enablePurgeProtection | grep -q true"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 5. NETWORKING VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_resource "VNet exists" \
    "az network vnet show --name $VNET_NAME --resource-group $RESOURCE_GROUP --query name"

test_resource "VNet has 3 subnets" \
    "az network vnet show --name $VNET_NAME --resource-group $RESOURCE_GROUP --query 'length(subnets)' | grep -q 3"

test_resource "NSG exists" \
    "az network nsg show --name $NSG_NAME --resource-group $RESOURCE_GROUP --query name"

test_resource "NSG has security rules" \
    "az network nsg show --name $NSG_NAME --resource-group $RESOURCE_GROUP --query 'length(securityRules)' | grep -q '[1-9]'"

test_resource "Private Endpoint exists" \
    "az network private-endpoint show --name $PRIVATE_ENDPOINT_NAME --resource-group $RESOURCE_GROUP --query name"

test_resource "Private Endpoint is connected" \
    "az network private-endpoint show --name $PRIVATE_ENDPOINT_NAME --resource-group $RESOURCE_GROUP --query 'privateLinkServiceConnections[0].privateLinkServiceConnectionState.status' | grep -q Approved"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 6. MONITORING VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_resource "Application Insights exists" \
    "az monitor app-insights component show --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP --query name"

test_resource "Log Analytics Workspace exists" \
    "az monitor log-analytics workspace show --workspace-name $LOG_ANALYTICS_NAME --resource-group $RESOURCE_GROUP --query name"

test_resource "Application Insights is receiving data" \
    "az monitor app-insights component show --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP --query provisioningState | grep -q Succeeded"

test_resource "Metric Alerts are configured" \
    "az monitor metrics alert list --resource-group $RESOURCE_GROUP --query 'length(@)' | grep -q '[4-9]'"

test_resource "Action Group exists" \
    "az monitor action-group list --resource-group $RESOURCE_GROUP --query 'length(@)' | grep -q '[1-9]'"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 7. IDENTITY & ACCESS VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_resource "App Service Managed Identity has Principal ID" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query identity.principalId"

test_resource "VNet Integration is configured" \
    "az webapp vnet-integration list --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query 'length(@)' | grep -q '[1-9]'"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 8. COMPLIANCE & TAGGING VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_resource "Resource Group has 'Environment' tag" \
    "az group show --name $RESOURCE_GROUP --query tags.Environment | grep -q dev"

test_resource "Resource Group has 'Workshop' tag" \
    "az group show --name $RESOURCE_GROUP --query tags.Workshop | grep -q true"

test_resource "App Service has required tags" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query 'tags.Environment' | grep -q dev"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 TEST SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Total Tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ ALL TESTS PASSED - Infrastructure is healthy! 🚀  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  SOME TESTS FAILED - Pass Rate: $PASS_RATE%            ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
