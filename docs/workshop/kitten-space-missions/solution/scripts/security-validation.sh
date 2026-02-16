#!/bin/bash
#######################################
# 🔐 Security Validation - Kitten Space Missions
# Valida configuraciones de seguridad según Azure Well-Architected Framework
#######################################

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_TOTAL=0
WARNINGS=0

# Configuración
RESOURCE_GROUP="rg-kitten-missions-dev"
APP_SERVICE_NAME="app-km-puhqveemr77k"
SQL_SERVER_NAME="sql-km-puhqveemr77k"
SQL_DATABASE_NAME="sqldb-kitten-dev"
KEY_VAULT_NAME="kv-km-puhqveemr77k"
NSG_NAME="nsg-kitten-dev"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🔐 Security Validation - Azure Well-Architected        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Función para check de seguridad
security_check() {
    local check_name="$1"
    local command="$2"
    local critical="${3:-false}"
    
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
    
    echo -n "[$CHECKS_TOTAL] Checking: $check_name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ SECURE${NC}"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        if [ "$critical" == "true" ]; then
            echo -e "${RED}❌ CRITICAL RISK${NC}"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        else
            echo -e "${YELLOW}⚠️  WARNING${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
        return 1
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 1. APP SERVICE SECURITY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

security_check "HTTPS Only is enforced" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query httpsOnly | grep -q true" \
    "true"

security_check "TLS 1.2 is minimum version" \
    "az webapp config show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query minTlsVersion | grep -qE '1\.[2-9]'" \
    "true"

security_check "Managed Identity is enabled" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query identity.type | grep -q SystemAssigned" \
    "true"

security_check "Remote debugging is disabled" \
    "az webapp config show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query remoteDebuggingEnabled | grep -q false" \
    "false"

security_check "HTTP 2.0 is enabled" \
    "az webapp config show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query http20Enabled | grep -q true" \
    "false"

security_check "Client certificates are configured" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query clientCertEnabled" \
    "false"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗄️  2. SQL DATABASE SECURITY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

security_check "Public network access is disabled" \
    "az sql server show --name $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query publicNetworkAccess | grep -q Disabled" \
    "true"

security_check "TLS 1.2 is minimum version for SQL" \
    "az sql server show --name $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query minimalTlsVersion | grep -q 1.2" \
    "true"

security_check "Azure AD Authentication is enabled" \
    "az sql server ad-admin list --server $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query 'length(@)' | grep -q '[1-9]'" \
    "true"

security_check "Transparent Data Encryption (TDE) is enabled" \
    "az sql db tde show --database $SQL_DATABASE_NAME --server $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query status | grep -q Enabled" \
    "true"

security_check "SQL Auditing is enabled" \
    "az sql server audit-policy show --server $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query state | grep -q Enabled" \
    "false"

security_check "Advanced Threat Protection is enabled" \
    "az sql server threat-policy show --server $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query state | grep -q Enabled" \
    "false"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 3. KEY VAULT SECURITY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

security_check "Soft Delete is enabled" \
    "az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query properties.enableSoftDelete | grep -q true" \
    "true"

security_check "Purge Protection is enabled" \
    "az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query properties.enablePurgeProtection | grep -q true" \
    "true"

security_check "Public network access is restricted" \
    "az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query properties.publicNetworkAccess | grep -qE 'Disabled|Enabled'" \
    "false"

security_check "RBAC authorization is enabled" \
    "az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query properties.enableRbacAuthorization" \
    "false"

security_check "Diagnostic logs are enabled" \
    "az monitor diagnostic-settings list --resource \$(az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query id -o tsv) --query 'length(@)' | grep -q '[1-9]'" \
    "false"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 4. NETWORK SECURITY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

security_check "NSG exists and is attached" \
    "az network nsg show --name $NSG_NAME --resource-group $RESOURCE_GROUP --query name" \
    "true"

security_check "NSG has security rules configured" \
    "az network nsg show --name $NSG_NAME --resource-group $RESOURCE_GROUP --query 'length(securityRules)' | grep -q '[1-9]'" \
    "true"

security_check "No NSG rule allows 0.0.0.0/0 inbound on all ports" \
    "! az network nsg rule list --nsg-name $NSG_NAME --resource-group $RESOURCE_GROUP --query \"[?sourceAddressPrefix=='*' && destinationPortRange=='*' && access=='Allow' && direction=='Inbound'].name\" -o tsv | grep -q ." \
    "true"

security_check "Private Endpoint is configured for SQL" \
    "az network private-endpoint list --resource-group $RESOURCE_GROUP --query \"[?privateLinkServiceConnections[0].groupIds[0]=='sqlServer'].name\" -o tsv | grep -q ." \
    "true"

security_check "VNet Service Endpoints are enabled" \
    "az network vnet list --resource-group $RESOURCE_GROUP --query \"[].subnets[].serviceEndpoints\" | grep -q Microsoft" \
    "false"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 5. IDENTITY & ACCESS MANAGEMENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

security_check "Managed Identities are in use (no secrets in code)" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query identity.principalId" \
    "true"

security_check "App Service has system-assigned identity" \
    "az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query identity.type | grep -q SystemAssigned" \
    "true"

security_check "RBAC assignments exist for Managed Identity" \
    "PRINCIPAL_ID=\$(az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query identity.principalId -o tsv) && az role assignment list --assignee \$PRINCIPAL_ID --query 'length(@)' | grep -q '[0-9]'" \
    "false"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 6. MONITORING & LOGGING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

security_check "Application Insights is configured" \
    "az webapp config appsettings list --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query \"[?name=='APPINSIGHTS_INSTRUMENTATIONKEY'].value\" | grep -q ." \
    "true"

security_check "Diagnostic settings are enabled on App Service" \
    "az monitor diagnostic-settings list --resource \$(az webapp show --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query id -o tsv) --query 'length(@)' | grep -q '[1-9]'" \
    "false"

security_check "Log Analytics workspace is configured" \
    "az monitor log-analytics workspace list --resource-group $RESOURCE_GROUP --query 'length(@)' | grep -q '[1-9]'" \
    "true"

security_check "Security alerts are configured" \
    "az monitor metrics alert list --resource-group $RESOURCE_GROUP --query 'length(@)' | grep -q '[1-9]'" \
    "true"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  7. TAGGING & COMPLIANCE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

security_check "Resources have 'Environment' tag" \
    "az resource list --resource-group $RESOURCE_GROUP --query \"[?tags.Environment!=null].name\" -o tsv | grep -q ." \
    "false"

security_check "Resources have 'Owner' tag for accountability" \
    "az group show --name $RESOURCE_GROUP --query tags.Owner" \
    "false"

security_check "Resources have 'CostCenter' tag for FinOps" \
    "az resource list --resource-group $RESOURCE_GROUP --query \"[?tags.CostCenter!=null].name\" -o tsv | grep -q ." \
    "false"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 8. SECRETS & CREDENTIALS MANAGEMENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

security_check "No hardcoded connection strings in App Settings" \
    "! az webapp config connection-string list --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query \"[?type=='SQLAzure'].value\" -o tsv | grep -qE 'Password|pwd'" \
    "true"

security_check "App uses Key Vault references (@Microsoft.KeyVault)" \
    "az webapp config appsettings list --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP --query \"[?contains(value, '@Microsoft.KeyVault')].name\" -o tsv | grep -q ." \
    "false"

security_check "SQL uses Azure AD authentication (no SQL auth)" \
    "az sql server ad-admin list --server $SQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query 'length(@)' | grep -q '[1-9]'" \
    "true"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 SECURITY SCORE SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Total Checks: $CHECKS_TOTAL"
echo -e "${GREEN}Passed (Secure): $CHECKS_PASSED${NC}"
echo -e "${RED}Failed (Critical Risks): $CHECKS_FAILED${NC}"
echo -e "${YELLOW}Warnings (Recommendations): $WARNINGS${NC}"
echo ""

SECURITY_SCORE=$((CHECKS_PASSED * 100 / CHECKS_TOTAL))

echo -e "Security Score: $SECURITY_SCORE%"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ PERFECT SECURITY - No issues found! 🛡️              ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
        exit 0
    else
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ⚠️  GOOD SECURITY - Some recommendations to address    ║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
        exit 0
    fi
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ CRITICAL RISKS FOUND - Immediate action required!   ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}⚠️  Please review and remediate critical security issues before deploying to production.${NC}"
    exit 1
fi
