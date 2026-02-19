#!/bin/bash
# ============================================================================
# Script de Despliegue: Azure AI Foundry para IP Editorial
# Tenant: FEMXA Formación S.L. (efbe317b-6cdb-46bd-82a7-d5fa8fbcb7e4)
# Subscription: Microsoft Azure (femxaformacion): #1003512
# ============================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# CONFIGURACIÓN (Modificar según necesidad)
# ============================================================================

TENANT_ID="efbe317b-6cdb-46bd-82a7-d5fa8fbcb7e4"
SUBSCRIPTION_ID="468c07e9-6936-4ad7-9399-ce402bb0f38a"
RESOURCE_GROUP="RG-NorthEurope-IPE-WVD-PWRPA"
LOCATION="eastus2"

# Nombre del recurso Azure AI Services
AI_SERVICES_NAME="openai-ipe-001"

BICEP_FILE="$(dirname "$0")/ai-foundry.bicep"
PARAMS_FILE="$(dirname "$0")/ai-foundry.parameters.json"

# ============================================================================
# VALIDACIONES PRE-DESPLIEGUE
# ============================================================================

echo -e "${YELLOW}🔍 Validando configuración...${NC}"

if [ "$AI_SERVICES_NAME" == "NOMBRE_PLACEHOLDER" ]; then
    echo -e "${RED}❌ ERROR: Debes especificar AI_SERVICES_NAME en el script${NC}"
    echo -e "${YELLOW}   Ejemplo: AI_SERVICES_NAME=\"openai-ipe-rpa\"${NC}"
    exit 1
fi

# Verificar que estamos en el tenant correcto
echo -e "${YELLOW}🔐 Autenticando en tenant FEMXA...${NC}"
az login --tenant "$TENANT_ID" --only-show-errors
az account set --subscription "$SUBSCRIPTION_ID"

CURRENT_TENANT=$(az account show --query tenantId -o tsv)
if [ "$CURRENT_TENANT" != "$TENANT_ID" ]; then
    echo -e "${RED}❌ ERROR: Tenant incorrecto${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Autenticado en tenant FEMXA${NC}"

# Verificar que el RG existe
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${RED}❌ ERROR: Resource Group $RESOURCE_GROUP no existe${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Resource Group encontrado: $RESOURCE_GROUP${NC}"

# Verificar que el nombre no está en uso
if az cognitiveservices account show --name "$AI_SERVICES_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${RED}❌ ERROR: Ya existe un recurso con nombre $AI_SERVICES_NAME${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Nombre disponible: $AI_SERVICES_NAME${NC}"

# ============================================================================
# ACTUALIZAR PARÁMETROS
# ============================================================================

echo -e "${YELLOW}📝 Actualizando parámetros...${NC}"

# Crear archivo de parámetros temporal con el nombre correcto
TEMP_PARAMS="/tmp/ai-foundry-params-$$.json"
jq --arg name "$AI_SERVICES_NAME" \
   '.parameters.aiServicesName.value = $name' \
   "$PARAMS_FILE" > "$TEMP_PARAMS"

# ============================================================================
# VALIDACIÓN BICEP
# ============================================================================

echo -e "${YELLOW}🔍 Validando plantilla Bicep...${NC}"
az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$BICEP_FILE" \
    --parameters "@$TEMP_PARAMS" \
    --only-show-errors

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Plantilla Bicep válida${NC}"
else
    echo -e "${RED}❌ ERROR: Plantilla Bicep inválida${NC}"
    rm -f "$TEMP_PARAMS"
    exit 1
fi

# ============================================================================
# WHAT-IF DEPLOYMENT
# ============================================================================

echo -e "${YELLOW}📊 Ejecutando What-If...${NC}"
az deployment group what-if \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$BICEP_FILE" \
    --parameters "@$TEMP_PARAMS"

echo ""
read -p "¿Continuar con el despliegue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}⚠️  Despliegue cancelado por el usuario${NC}"
    rm -f "$TEMP_PARAMS"
    exit 0
fi

# ============================================================================
# DESPLIEGUE
# ============================================================================

echo -e "${YELLOW}🚀 Iniciando despliegue...${NC}"
DEPLOYMENT_NAME="ai-foundry-ipe-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$BICEP_FILE" \
    --parameters "@$TEMP_PARAMS" \
    --verbose

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Despliegue completado exitosamente${NC}"
else
    echo -e "${RED}❌ ERROR: Fallo en el despliegue${NC}"
    rm -f "$TEMP_PARAMS"
    exit 1
fi

# ============================================================================
# OUTPUTS Y CONFIGURACIÓN POWER PLATFORM
# ============================================================================

echo -e "${YELLOW}📋 Obteniendo información del despliegue...${NC}"

ENDPOINT=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.outputs.aiServicesEndpoint.value" -o tsv)

API_KEY=$(az cognitiveservices account keys list \
    --name "$AI_SERVICES_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "key1" -o tsv)

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  DESPLIEGUE COMPLETADO${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}📝 INFORMACIÓN PARA POWER PLATFORM:${NC}"
echo ""
echo "  Endpoint:"
echo "    $ENDPOINT"
echo ""
echo "  API Key (PRIMARY):"
echo "    $API_KEY"
echo ""
echo "  Deployment GPT-5-nano:"
echo "    gpt-5-nano"
echo ""
echo "  Deployment GPT-5-mini:"
echo "    gpt-5-mini"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE: Almacena la API Key en Key Vault${NC}"
echo ""
echo "Comando para almacenar en Key Vault:"
echo "  az keyvault secret set \\"
echo "    --vault-name KeyVaultIPERPA \\"
echo "    --name openai-api-key \\"
echo "    --value \"$API_KEY\""
echo ""
echo -e "${GREEN}Deployment finalizado: $DEPLOYMENT_NAME${NC}"
echo ""

# Cleanup
rm -f "$TEMP_PARAMS"
