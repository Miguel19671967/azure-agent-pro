# 🐱🚀 Kitten Space Missions API - Solution

Architecture solution for Kitten Space Missions API REST, designed with Azure Well-Architected Framework and deployed using Infrastructure as Code (Bicep).

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Cost Analysis](#cost-analysis)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Options](#deployment-options)
- [Project Structure](#project-structure)
- [Security](#security)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This solution provides a complete enterprise-grade infrastructure for a REST API that manages space missions crewed by feline astronauts.

**Key Features:**
- ✅ **Infrastructure as Code**: 100% Bicep, modular and reusable
- ✅ **Security**: Managed Identities, Private Endpoints, Zero Trust networking
- ✅ **Observability**: Application Insights + Log Analytics integrated
- ✅ **Cost-Optimized**: ~€26.53/month in dev environment (47% below budget)
- ✅ **Auto-scaling**: 1-3 instances based on CPU load
- ✅ **CI/CD**: GitHub Actions workflows for validation and deployment

**Azure Services Used:**
- App Service (B1)
- Azure SQL Database (Basic)
- Virtual Network + NSG
- Private Endpoint
- Key Vault (Standard)
- Application Insights
- Log Analytics

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        INTERNET                              │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  App Service (B1) + Managed Identity                         │
│  ├─ VNet Integration                                         │
│  ├─ Application Insights                                     │
│  └─ Key Vault References                                     │
└───────────────────┬──────────────────────────────────────────┘
                    │
          ┌─────────┴─────────┐
          │                   │
          ▼                   ▼
    ┌─────────────┐    ┌──────────────────┐
    │  Key Vault  │    │  Virtual Network │
    │  (Standard) │    │  (10.0.0.0/16)   │
    └─────────────┘    └────────┬─────────┘
                                │
                       ┌────────┴────────┐
                       │ Private Endpoint│
                       │   (SQL)         │
                       └────────┬────────┘
                                │
                                ▼
                    ┌────────────────────────┐
                    │  Azure SQL Database    │
                    │  (Basic, 2GB, 5 DTU)   │
                    │  Public Access: OFF    │
                    └────────────────────────┘
```

For detailed architecture documentation, see: [ADD.md](ADD.md)

## 💰 Cost Analysis

**Monthly Cost Breakdown (Development):**

| Resource | SKU | Monthly Cost |
|----------|-----|--------------|
| App Service Plan | B1 | €12.00 |
| Private Endpoint | Standard | €7.00 |
| SQL Database | Basic | €4.50 |
| Application Insights | PAYG | €2.00 |
| Log Analytics | PAYG | €1.00 |
| Key Vault | Standard | €0.03 |
| **TOTAL** | | **€26.53** |

**Budget Status:** 53% utilized (€26.53 / €50.00)

For detailed cost analysis and optimization recommendations, see: [FINOPS_REPORT.html](FINOPS_REPORT.html)

## 📝 Prerequisites

### Required Tools
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (v2.50+)
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) (included with Azure CLI)
- [Git](https://git-scm.com/downloads)
- Bash shell (Linux, macOS, WSL2)

### Azure Requirements
- Active Azure subscription (Ionela Morar - MPN: `e507bceb-37fc-4a08-be9b-c2fd25224ec3`)
- Permissions: Contributor or Owner on subscription
- Azure AD user account (for SQL AAD admin and Key Vault access)

### Get Your Azure AD Information
```bash
# Get your Object ID
az ad signed-in-user show --query id -o tsv

# Get your User Principal Name (UPN)
az ad signed-in-user show --query userPrincipalName -o tsv
```

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone <repo-url>
cd azure-agent-pro/docs/workshop/kitten-space-missions/solution
```

### 2. Configure Parameters
Edit `bicep/parameters/dev.bicepparam` and replace:
- `YOUR_OBJECT_ID_HERE` with your Azure AD Object ID
- `ionela.morar@...` with your User Principal Name

```bicep
param sqlAadAdminObjectId = 'YOUR_OBJECT_ID_HERE'
param sqlAadAdminLogin = 'your-upn@domain.com'
param keyVaultAdminObjectIds = ['YOUR_OBJECT_ID_HERE']
```

### 3. Login to Azure
```bash
az login
az account set --subscription "e507bceb-37fc-4a08-be9b-c2fd25224ec3"
```

### 4. Deploy Infrastructure
```bash
# Using deployment script (recommended)
./scripts/deploy.sh dev

# Or manually
cd bicep
az group create --name rg-kitten-missions-dev --location westeurope
az deployment group create \
  --resource-group rg-kitten-missions-dev \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam
```

### 5. Configure SQL Permissions
```bash
./scripts/configure-sql-permissions.sh dev
```

### 6. Verify Deployment
```bash
# Get App Service URL
az deployment group show \
  --resource-group rg-kitten-missions-dev \
  --name <deployment-name> \
  --query properties.outputs.appServiceUrl.value -o tsv

# Test health endpoint (once app code is deployed)
curl https://app-kitten-missions-dev.azurewebsites.net/health
```

## 📦 Deployment Options

### Option 1: Local Deployment (Bash Script)
```bash
./scripts/deploy.sh dev
```
**Features:**
- ✅ Interactive what-if analysis
- ✅ Automatic validation
- ✅ User-friendly output with colors
- ✅ Deployment summary with next steps

### Option 2: GitHub Actions (CI/CD)
```bash
# Push to trigger deployment
git add .
git commit -m "Deploy infrastructure"
git push origin main
```
**Requires GitHub Secrets:**
- `AZURE_CLIENT_ID` (for OIDC)
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `SQL_AAD_ADMIN_OBJECT_ID`
- `SQL_AAD_ADMIN_LOGIN`

### Option 3: Manual Azure CLI
```bash
cd bicep

# Validate
az deployment group validate \
  --resource-group rg-kitten-missions-dev \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam

# What-if
az deployment group what-if \
  --resource-group rg-kitten-missions-dev \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam

# Deploy
az deployment group create \
  --resource-group rg-kitten-missions-dev \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam
```

## 📁 Project Structure

```
solution/
├── bicep/
│   ├── main.bicep                    # Main orchestrator
│   ├── modules/
│   │   ├── virtual-network.bicep     # VNet + NSG
│   │   ├── sql-database.bicep        # SQL + Private Endpoint
│   │   ├── key-vault.bicep           # Key Vault
│   │   ├── app-service.bicep         # App Service + Plan
│   │   └── monitoring.bicep          # App Insights + Log Analytics
│   └── parameters/
│       └── dev.bicepparam            # Development parameters
├── .github/
│   └── workflows/
│       ├── validate.yml              # PR validation workflow
│       └── deploy.yml                # Deployment workflow
├── scripts/
│   ├── deploy.sh                     # Deployment script
│   └── configure-sql-permissions.sh  # SQL MI permissions setup
├── ADD.md                            # Architecture Design Document
├── FINOPS_REPORT.html                # Cost analysis report
└── README.md                         # This file
```

## 🔐 Security

### Authentication & Authorization
- ✅ **Managed Identities**: App Service uses SystemAssigned MI (no passwords)
- ✅ **Azure AD Authentication**: SQL Server configured for AAD-only auth
- ✅ **RBAC**: Key Vault uses role-based access control
- ✅ **Secrets Management**: All secrets in Key Vault, referenced via Key Vault references

### Network Security
- ✅ **Private Endpoints**: SQL Database isolated from internet
- ✅ **NSG Rules**: Restrictive inbound/outbound rules
- ✅ **VNet Integration**: App Service routes traffic through VNet
- ✅ **Service Endpoints**: Enabled for SQL, Key Vault, Storage
- ✅ **HTTPS Only**: TLS 1.2 minimum enforced
- ✅ **Public Access Disabled**: SQL Database not accessible from internet

### Monitoring & Compliance
- ✅ **Diagnostic Logs**: Enabled on all resources
- ✅ **Application Insights**: End-to-end tracing
- ✅ **Security Scanning**: Checkov integration in CI/CD
- ✅ **Budget Alerts**: Configured at 70%, 90%, 100%

## 📊 Monitoring

### Application Insights
- Request tracking (latency, throughput)
- Dependency tracking (SQL queries)
- Exception tracking
- Custom metrics
- Live metrics stream

**Access:**
```bash
# Get Application Insights name
az deployment group show \
  --resource-group rg-kitten-missions-dev \
  --name <deployment-name> \
  --query properties.outputs.applicationInsightsName.value -o tsv

# Open in portal
az monitor app-insights component show \
  --app <app-insights-name> \
  --resource-group rg-kitten-missions-dev
```

### Log Analytics
- Centralized logging for all resources
- KQL queries for advanced analysis
- 30-day retention (configurable)

**Useful KQL Queries:**
```kql
// Request latency p95
requests
| where timestamp > ago(1h)
| summarize percentile(duration, 95) by bin(timestamp, 5m)
| render timechart

// Failed requests
requests
| where success == false
| summarize count() by resultCode
| render piechart

// SQL dependency performance
dependencies
| where type == "SQL"
| summarize avg(duration), count() by target
| render barchart
```

### Alerts Configured
- High error rate (>10% failed requests)
- High latency (p95 > 500ms)

## 🐛 Troubleshooting

### Common Issues

#### 1. Deployment fails with "Object ID not found"
**Solution:** Ensure you've replaced placeholders in `dev.bicepparam`:
```bash
# Get your Object ID
az ad signed-in-user show --query id -o tsv
```

#### 2. SQL Connection fails from App Service
**Cause:** Managed Identity permissions not configured

**Solution:**
```bash
./scripts/configure-sql-permissions.sh dev
```

#### 3. Key Vault access denied
**Cause:** RBAC role not assigned

**Solution:**
```bash
# Assign Key Vault Secrets User role
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee <app-service-principal-id> \
  --scope <key-vault-id>
```

#### 4. Private Endpoint DNS resolution fails
**Cause:** Private DNS Zone not linked to VNet

**Solution:** Already handled by Bicep, but verify:
```bash
az network private-dns link vnet list \
  --resource-group rg-kitten-missions-dev \
  --zone-name privatelink.database.windows.net
```

#### 5. Health endpoint returns 503
**Cause:** Application code not deployed yet

**Solution:** Deploy your API code to App Service:
```bash
# Publish .NET app
cd <your-api-project>
dotnet publish -c Release
cd bin/Release/net8.0/publish
zip -r publish.zip *

# Deploy to Azure
az webapp deploy \
  --name app-kitten-missions-dev \
  --resource-group rg-kitten-missions-dev \
  --src-path publish.zip
```

### Diagnostic Commands

```bash
# Check resource group
az group show --name rg-kitten-missions-dev

# List all resources
az resource list --resource-group rg-kitten-missions-dev --output table

# Check App Service logs
az webapp log tail --name app-kitten-missions-dev --resource-group rg-kitten-missions-dev

# Test SQL connectivity (from Azure Cloud Shell)
az sql db execute \
  --resource-group rg-kitten-missions-dev \
  --server sql-kitten-missions-dev \
  --database sqldb-kitten-missions-dev \
  --sql "SELECT @@VERSION"

# View Application Insights data
az monitor app-insights query \
  --app appi-kitten-missions-dev \
  --resource-group rg-kitten-missions-dev \
  --analytics-query "requests | take 10"
```

## 📚 Additional Resources

- [Architecture Design Document (ADD)](ADD.md) - Complete architecture documentation
- [FinOps Report](FINOPS_REPORT.html) - Detailed cost analysis and optimization recommendations
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [App Service VNet Integration](https://learn.microsoft.com/azure/app-service/overview-vnet-integration)
- [SQL Private Endpoints](https://learn.microsoft.com/azure/azure-sql/database/private-endpoint-overview)

## 🎯 Next Steps

1. ✅ **Deploy Infrastructure** (you are here)
2. ⬜ **Develop API Code** (.NET 8 / Node.js / Python)
3. ⬜ **Create Database Schema** (migrations, seed data)
4. ⬜ **Deploy Application** to App Service
5. ⬜ **Run Integration Tests**
6. ⬜ **Configure Monitoring Dashboards**
7. ⬜ **Performance Testing** (load testing, stress testing)
8. ⬜ **Security Review** (penetration testing, vulnerability scanning)
9. ⬜ **Documentation** (API docs, runbooks, troubleshooting guides)
10. ⬜ **Go Live** preparation

## 📞 Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review Azure deployment logs
3. Check Application Insights for errors
4. Review [ADD.md](ADD.md) for architecture details

---

**Last Updated:** 2026-02-16  
**Version:** 1.0  
**Subscription:** Ionela Morar - MPN (`e507bceb-37fc-4a08-be9b-c2fd25224ec3`)  
**Maintained by:** Azure_Architect_Pro
