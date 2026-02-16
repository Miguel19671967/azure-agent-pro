#!/bin/bash
# ============================================================================
# DEPLOYMENT SCRIPT - Kitten Space Missions
# ============================================================================
# Script para desplegar infraestructura Azure localmente
# Uso: ./deploy.sh [environment]
# Ejemplo: ./deploy.sh dev
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

ENVIRONMENT=${1:-"dev"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BICEP_DIR="$(dirname "$SCRIPT_DIR")/bicep"
PROJECT_NAME="kitten-missions"
LOCATION="westeurope"
SUBSCRIPTION_ID="e507bceb-37fc-4a08-be9b-c2fd25224ec3"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not found. Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
    log_success "Azure CLI found: $AZ_VERSION"
    
    # Check Bicep CLI
    if ! command -v bicep &> /dev/null; then
        log_warning "Bicep CLI not found. Installing..."
        az bicep install
    fi
    log_success "Bicep CLI found: $(az bicep version)"
    
    # Check login status
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Run: az login"
        exit 1
    fi
    log_success "Logged in as: $(az account show --query user.name -o tsv)"
}

set_subscription() {
    log_info "Setting Azure subscription..."
    
    CURRENT_SUB=$(az account show --query id -o tsv)
    
    if [[ "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]]; then
        log_warning "Switching to subscription: $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
    
    log_success "Using subscription: $(az account show --query name -o tsv)"
}

create_resource_group() {
    local RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"
    
    log_info "Creating resource group: $RG_NAME"
    
    if az group show --name "$RG_NAME" &> /dev/null; then
        log_warning "Resource group already exists"
    else
        az group create \
            --name "$RG_NAME" \
            --location "$LOCATION" \
            --tags "Project=Kitten Space Missions" "Environment=$ENVIRONMENT" "ManagedBy=Bicep-IaC"
        log_success "Resource group created"
    fi
}

get_user_info() {
    log_info "Getting user information for AAD configuration..."
    
    USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
    USER_UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv)
    
    log_success "User Object ID: $USER_OBJECT_ID"
    log_success "User UPN: $USER_UPN"
    
    export USER_OBJECT_ID
    export USER_UPN
}

validate_deployment() {
    local RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"
    
    log_info "Validating Bicep deployment..."
    
    cd "$BICEP_DIR"
    
    az deployment group validate \
        --resource-group "$RG_NAME" \
        --template-file main.bicep \
        --parameters "parameters/${ENVIRONMENT}.bicepparam" \
        --parameters sqlAadAdminObjectId="$USER_OBJECT_ID" \
        --parameters sqlAadAdminLogin="$USER_UPN" \
        --parameters keyVaultAdminObjectIds="['$USER_OBJECT_ID']"
    
    log_success "Validation passed"
}

what_if_deployment() {
    local RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"
    
    log_info "Running What-If analysis..."
    
    cd "$BICEP_DIR"
    
    az deployment group what-if \
        --resource-group "$RG_NAME" \
        --template-file main.bicep \
        --parameters "parameters/${ENVIRONMENT}.bicepparam" \
        --parameters sqlAadAdminObjectId="$USER_OBJECT_ID" \
        --parameters sqlAadAdminLogin="$USER_UPN" \
        --parameters keyVaultAdminObjectIds="['$USER_OBJECT_ID']" \
        --result-format FullResourcePayloads
    
    echo ""
    read -p "Do you want to proceed with deployment? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        log_warning "Deployment cancelled by user"
        exit 0
    fi
}

deploy_infrastructure() {
    local RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"
    local DEPLOYMENT_NAME="deploy-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Deploying infrastructure..."
    log_info "Deployment name: $DEPLOYMENT_NAME"
    
    cd "$BICEP_DIR"
    
    az deployment group create \
        --resource-group "$RG_NAME" \
        --template-file main.bicep \
        --parameters "parameters/${ENVIRONMENT}.bicepparam" \
        --parameters sqlAadAdminObjectId="$USER_OBJECT_ID" \
        --parameters sqlAadAdminLogin="$USER_UPN" \
        --parameters keyVaultAdminObjectIds="['$USER_OBJECT_ID']" \
        --name "$DEPLOYMENT_NAME" \
        --verbose
    
    log_success "Deployment completed: $DEPLOYMENT_NAME"
    
    # Save deployment name for later use
    export DEPLOYMENT_NAME
}

show_deployment_outputs() {
    local RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"
    
    log_info "Deployment outputs:"
    
    az deployment group show \
        --resource-group "$RG_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs \
        --output table
    
    # Get specific outputs
    APP_SERVICE_URL=$(az deployment group show \
        --resource-group "$RG_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.appServiceUrl.value -o tsv)
    
    APP_SERVICE_NAME=$(az deployment group show \
        --resource-group "$RG_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.appServiceName.value -o tsv)
    
    SQL_SERVER_NAME=$(az deployment group show \
        --resource-group "$RG_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.sqlServerName.value -o tsv)
    
    SQL_DB_NAME=$(az deployment group show \
        --resource-group "$RG_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.sqlDatabaseName.value -o tsv)
    
    KEY_VAULT_NAME=$(az deployment group show \
        --resource-group "$RG_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.keyVaultName.value -o tsv)
    
    echo ""
    log_success "==================================================="
    log_success "DEPLOYMENT SUCCESSFUL!"
    log_success "==================================================="
    echo ""
    log_info "📱 App Service: $APP_SERVICE_NAME"
    log_info "🌐 URL: $APP_SERVICE_URL"
    log_info "🗄️  SQL Server: $SQL_SERVER_NAME"
    log_info "💾 Database: $SQL_DB_NAME"
    log_info "🔐 Key Vault: $KEY_VAULT_NAME"
    echo ""
    log_warning "📋 NEXT STEPS:"
    echo "1. Configure SQL permissions:"
    echo "   ./scripts/configure-sql-permissions.sh $ENVIRONMENT"
    echo ""
    echo "2. Deploy application code:"
    echo "   cd api/"
    echo "   dotnet publish -c Release"
    echo "   az webapp deploy --name $APP_SERVICE_NAME --resource-group $RG_NAME --src-path ./publish.zip"
    echo ""
    echo "3. Test health endpoint:"
    echo "   curl $APP_SERVICE_URL/health"
    echo ""
    log_success "==================================================="
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    log_info "╔═══════════════════════════════════════════════════╗"
    log_info "║   Kitten Space Missions - Deployment Script      ║"
    log_info "║   Environment: $ENVIRONMENT                              ║"
    log_info "╚═══════════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    set_subscription
    get_user_info
    create_resource_group
    validate_deployment
    what_if_deployment
    deploy_infrastructure
    show_deployment_outputs
    
    echo ""
    log_success "🎉 Deployment workflow completed successfully!"
    echo ""
}

# Run main
main
