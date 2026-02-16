# Kitten Space Missions - Bicep Infrastructure

## 📁 Estructura de Archivos

```
bicep/
├── main.bicep                          # Orquestador principal
├── modules/
│   ├── app-service.bicep               # App Service + Plan B1
│   ├── key-vault.bicep                 # Key Vault Standard
│   ├── monitoring.bicep                # App Insights + Log Analytics
│   ├── sql-database.bicep              # SQL Server + Database Basic
│   ├── virtual-network.bicep           # VNet + Subnets + NSG
│   ├── private-endpoint.bicep          # Private Endpoint genérico
│   └── rbac.bicep                      # Role assignments
└── parameters/
    ├── dev.parameters.json             # Parámetros dev (Scenario B)
    ├── dev.bicepparam                  # Parámetros dev (formato nativo)
    └── prod.parameters.json            # Parámetros prod (Scenario C)
```

## � Diagrama de Dependencias

```
main.bicep
│
├──► monitoring.bicep
│    └── Outputs: Log Analytics ID, App Insights ID, connection strings
│
├──► virtual-network.bicep
│    └── Outputs: VNet ID, App Subnet ID, PE Subnet ID, NSG ID
│
├──► key-vault.bicep
│    ├── DependsOn: monitoring (diagnostic settings)
│    └── Outputs: Key Vault URI, Key Vault ID
│
├──► sql-database.bicep
│    ├── DependsOn: virtual-network (PE subnet), key-vault (connection string storage)
│    ├── DependsOn: monitoring (diagnostic settings)
│    └── Outputs: SQL Server FQDN, SQL Server ID, Database ID
│
├──► private-endpoint.bicep (SQL)
│    ├── DependsOn: sql-database (private link service ID)
│    ├── DependsOn: virtual-network (PE subnet)
│    └── Outputs: Private Endpoint ID, Private IP
│
├──► app-service.bicep
│    ├── DependsOn: virtual-network (app subnet for VNet integration)
│    ├── DependsOn: key-vault (connection strings via Key Vault references)
│    ├── DependsOn: monitoring (App Insights connection string)
│    └── Outputs: App Service Name, Default Hostname, Managed Identity Principal ID
│
└──► rbac.bicep
     ├── DependsOn: app-service (Managed Identity Principal ID)
     ├── DependsOn: key-vault, sql-database (resources to assign permissions)
     └── Outputs: Role Assignment IDs, RBAC Summary
```

**Orden de Deployment**:
1. `monitoring.bicep` → (Independiente) Log Analytics + App Insights
2. `virtual-network.bicep` → (Independiente) VNet + Subnets + NSG
3. `key-vault.bicep` → (Requiere: monitoring)
4. `sql-database.bicep` → (Requiere: virtual-network, key-vault, monitoring)
5. `private-endpoint.bicep` → (Requiere: sql-database, virtual-network)
6. `app-service.bicep` → (Requiere: virtual-network, key-vault, monitoring)
7. `rbac.bicep` → (Requiere: app-service, key-vault, sql-database)

## �🚀 Deployment

### Validar sintaxis

```bash
cd /home/mvallemonjas/azure-agent-pro/docs/workshop/kitten-space-missions/solution/bicep

# Validar main.bicep
az bicep build --file main.bicep

# Validar todos los módulos
az bicep build --file modules/app-service.bicep
az bicep build --file modules/sql-database.bicep
az bicep build --file modules/key-vault.bicep
az bicep build --file modules/monitoring.bicep
az bicep build --file modules/virtual-network.bicep
az bicep build --file modules/private-endpoint.bicep
az bicep build --file modules/rbac.bicep
```

### What-If Deployment (Preview cambios)

```bash
# Login a Azure
az login

# Set subscription
az account set --subscription "b5a68ec8-e110-4be5-b500-173db93ba29f"

# Create resource group
az group create \
  --name rg-kitten-dev \
  --location westeurope

# What-If usando JSON parameters
az deployment group what-if \
  --resource-group rg-kitten-dev \
  --template-file main.bicep \
  --parameters parameters/dev.parameters.json

# What-If usando bicepparam
az deployment group what-if \
  --resource-group rg-kitten-dev \
  --template-file main.bicep \
  --parameters dev.bicepparam
```

### Deploy Real

```bash
# DEV Environment
az deployment group create \
  --resource-group rg-kitten-dev \
  --template-file main.bicep \
  --parameters parameters/dev.parameters.json \
  --name deploy-kitten-dev-$(date +%Y%m%d-%H%M%S)

# PROD Environment (futuro)
az deployment group create \
  --resource-group rg-kitten-prod \
  --template-file main.bicep \
  --parameters parameters/prod.parameters.json \
  --name deploy-kitten-prod-$(date +%Y%m%d-%H%M%S)
```

## 📊 Scenario B (Dev) - Configuración Actual

| Recurso | SKU/Tier | Costo/mes | Justificación |
|---------|----------|-----------|---------------|
| App Service Plan | B1 Basic | $13.14 | VNet integration, dedicated CPU |
| SQL Database | Basic (5 DTU) | $4.90 | Suficiente para dev workload |
| Private Endpoint | Standard | $8.30 | Zero Trust architecture |
| Key Vault | Standard | $0.03 | Secret management |
| App Insights | PAYG | $2.88 | Telemetry completa en dev |
| VNet + NSG | Included | $0.00 | Sin cargos base |
| **TOTAL** | | **$29.25** | 42% del budget $70 |

Con auto-shutdown (Lun-Vie 8am-8pm): **$20.84/mes** ✅

## 🔒 Seguridad Implementada

- ✅ Managed Identity en App Service
- ✅ HTTPS only, TLS 1.2+ obligatorio
- ✅ SQL sin public access (Private Endpoint only)
- ✅ Secrets en Key Vault (no hardcoded)
- ✅ VNet integration + NSG rules
- ✅ Diagnostic settings en todos los recursos PaaS
- ✅ RBAC con least privilege (Key Vault Secrets User, SQL DB Contributor)

## 📈 Observability

Todos los recursos envían logs y metrics a Log Analytics:
- App Service: HTTP logs, metrics, application logs
- SQL Database: Query performance, errors, blocked queries
- Key Vault: Access audit logs
- Retention: 30 días (dev), 90 días (prod)

Alertas configuradas:
- HTTP 5xx > 10 en 5 minutos
- Response time p95 > 500ms
- Failed requests > 20%

## 🎯 Naming Conventions

```
Resource Group:    rg-{projectName}-{environment}
App Service:       app-{projectName}-{environment}-{uniqueString}
SQL Server:        sql-{projectName}-{environment}-{uniqueString}
Database:          sqldb-{projectName}-{environment}
Key Vault:         kv-{project}-{env}-{uniqueString}
VNet:              vnet-{projectName}-{environment}
App Insights:      appi-{projectName}-{environment}
Log Analytics:     log-{projectName}-{environment}
```

## 🧪 Post-Deployment Validation

```bash
# 1. Verificar recursos creados
az resource list --resource-group rg-kitten-dev --output table

# 2. Verificar App Service
az webapp show --name <app-name> --resource-group rg-kitten-dev --query state
az webapp config show --name <app-name> --resource-group rg-kitten-dev

# 3. Verificar SQL connectivity (desde App Service)
az webapp ssh --name <app-name> --resource-group rg-kitten-dev

# 4. Verificar Key Vault secrets
az keyvault secret list --vault-name <kv-name> --query "[].name"

# 5. Verificar Private Endpoint
az network private-endpoint list --resource-group rg-kitten-dev --output table

# 6. Verificar RBAC assignments
az role assignment list --resource-group rg-kitten-dev --output table
```

## 🛠️ Troubleshooting

### App Service no puede conectar a SQL

```bash
# Verificar VNet integration
az webapp vnet-integration list --name <app-name> --resource-group rg-kitten-dev

# Verificar Private Endpoint DNS
nslookup <sql-server>.database.windows.net

# Verificar Managed Identity permisos
az role assignment list --assignee <principal-id> --resource-group rg-kitten-dev
```

### Key Vault access denied

```bash
# Verificar access policy
az keyvault show --name <kv-name> --query properties.accessPolicies

# Verificar Managed Identity
az webapp identity show --name <app-name> --resource-group rg-kitten-dev

# Otorgar permisos manualmente si falta
az keyvault set-policy \
  --name <kv-name> \
  --object-id <principal-id> \
  --secret-permissions get list
```

## 📚 Referencias

- [Azure Naming Conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Bicep Best Practices](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)
- [FinOps Report](../docs/finops-report.html)
- [Cost Decision Record](../docs/cost-decision-record.md)

## 🔄 Actualización/Re-deployment

```bash
# Re-deploy con cambios incrementales
az deployment group create \
  --resource-group rg-kitten-dev \
  --template-file main.bicep \
  --parameters parameters/dev.parameters.json \
  --mode Incremental \
  --name redeploy-$(date +%Y%m%d-%H%M%S)

# Ver historial de deployments
az deployment group list --resource-group rg-kitten-dev --output table

# Ver detalles de deployment fallido
az deployment group show \
  --resource-group rg-kitten-dev \
  --name <deployment-name> \
  --query properties.error
```

## 🗑️ Cleanup

```bash
# Eliminar resource group completo (WARNING: destructivo)
az group delete --name rg-kitten-dev --yes --no-wait

# Eliminar solo deployment history (mantener recursos)
az deployment group delete \
  --resource-group rg-kitten-dev \
  --name <deployment-name>
```

---

**Last Updated**: 2026-02-16  
**Version**: 1.0  
**Maintained by**: Azure Architect Pro
