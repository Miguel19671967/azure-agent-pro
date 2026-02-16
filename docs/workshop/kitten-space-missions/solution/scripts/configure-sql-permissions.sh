#!/bin/bash
# ============================================================================
# SQL PERMISSIONS CONFIGURATION SCRIPT
# ============================================================================
# Configura permisos de Managed Identity del App Service en SQL Database
# Uso: ./configure-sql-permissions.sh [environment]
# ============================================================================

set -euo pipefail

ENVIRONMENT=${1:-"dev"}
PROJECT_NAME="kitten-missions"
RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

log_info "Retrieving deployment information..."

# Get latest deployment
DEPLOYMENT_NAME=$(az deployment group list \
    --resource-group "$RG_NAME" \
    --query "[?properties.provisioningState=='Succeeded'] | sort_by(@, &properties.timestamp) | [-1].name" \
    -o tsv)

log_info "Using deployment: $DEPLOYMENT_NAME"

# Get resource names from deployment outputs
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

SQL_FQDN=$(az deployment group show \
    --resource-group "$RG_NAME" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.sqlServerFqdn.value -o tsv)

log_info "App Service: $APP_SERVICE_NAME"
log_info "SQL Server: $SQL_SERVER_NAME"
log_info "SQL Database: $SQL_DB_NAME"

# Create SQL script
log_info "Creating SQL permissions script..."

cat > /tmp/configure-sql-permissions.sql << EOF
-- Kitten Space Missions - SQL Permissions Configuration
-- Auto-generated: $(date)

PRINT '=================================================';
PRINT 'Configuring permissions for App Service MI';
PRINT '=================================================';
PRINT '';

-- Create user for Managed Identity
PRINT 'Creating user for Managed Identity...';
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'${APP_SERVICE_NAME}')
BEGIN
    CREATE USER [${APP_SERVICE_NAME}] FROM EXTERNAL PROVIDER;
    PRINT '✅ User created successfully';
END
ELSE
BEGIN
    PRINT '⚠️  User already exists';
END
PRINT '';

-- Assign db_datareader role
PRINT 'Assigning db_datareader role...';
ALTER ROLE db_datareader ADD MEMBER [${APP_SERVICE_NAME}];
PRINT '✅ db_datareader role assigned';
PRINT '';

-- Assign db_datawriter role
PRINT 'Assigning db_datawriter role...';
ALTER ROLE db_datawriter ADD MEMBER [${APP_SERVICE_NAME}];
PRINT '✅ db_datawriter role assigned';
PRINT '';

-- Verify permissions
PRINT 'Verifying permissions...';
SELECT 
    dp.name AS UserName,
    dp.type_desc AS UserType,
    r.name AS RoleName
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE dp.name = '${APP_SERVICE_NAME}';

PRINT '';
PRINT '=================================================';
PRINT '✅ Configuration completed successfully!';
PRINT '=================================================';
EOF

log_success "SQL script created: /tmp/configure-sql-permissions.sql"

# Execute SQL script
log_warning "Executing SQL script..."
log_warning "Note: This requires connectivity to SQL Server from your current location"

# Try to execute SQL
if az sql db execute \
    --ids "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG_NAME}/providers/Microsoft.Sql/servers/${SQL_SERVER_NAME}/databases/${SQL_DB_NAME}" \
    --sql-file /tmp/configure-sql-permissions.sql 2>/dev/null; then
    log_success "SQL permissions configured successfully!"
else
    log_warning "Could not execute SQL directly (this is normal if Private Endpoint is configured)"
    echo ""
    echo "📋 MANUAL EXECUTION OPTIONS:"
    echo ""
    echo "Option 1: Azure Cloud Shell"
    echo "  1. Go to: https://shell.azure.com"
    echo "  2. Run: cat > configure-sql.sql << 'EOF'"
    echo "  3. Copy/paste content from: /tmp/configure-sql-permissions.sql"
    echo "  4. Run: az sql db execute --resource-group ${RG_NAME} --server ${SQL_SERVER_NAME} --database ${SQL_DB_NAME} --file configure-sql.sql"
    echo ""
    echo "Option 2: Azure Data Studio / SSMS"
    echo "  1. Connect to: ${SQL_FQDN}"
    echo "  2. Database: ${SQL_DB_NAME}"
    echo "  3. Authentication: Azure Active Directory"
    echo "  4. Execute script from: /tmp/configure-sql-permissions.sql"
    echo ""
    echo "Option 3: sqlcmd (if installed)"
    echo "  sqlcmd -S ${SQL_FQDN} -d ${SQL_DB_NAME} -G -i /tmp/configure-sql-permissions.sql"
    echo ""
fi

log_info "Script saved at: /tmp/configure-sql-permissions.sql"
