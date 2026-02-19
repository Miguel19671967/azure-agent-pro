# IP Editorial - Migración Power Platform + Azure AI Foundry

**Cliente:** IP Editorial (Ideas Propias Editorial, S.L.U.)  
**Tenant Origen:** ipeditorial.onmicrosoft.com  
**Tenant Destino:** femxaformacion.onmicrosoft.com  
**Proyecto:** Power Platform RPA con Azure OpenAI Integration  

---

## 📋 Resumen del Proyecto

Migración cross-tenant de solución Power Platform RPA desarrollada por Prodware (Ana Gutierrez) desde tenant IP Editorial hacia tenant FEMXA Formación S.L., incluyendo:

1. **Recreación de Azure AI Foundry** (AI Services) con modelos GPT-5-nano y GPT-5-mini
2. **Creación de entornos Power Platform** (DEV + PROD)
3. **Exportación e importación** de solución Power Platform
4. **Reconfiguración de connections** hacia el nuevo AI Foundry

---

## 🏗️ Infraestructura Azure (Tenant FEMXA)

### **Recursos Existentes:**
- ✅ VMs AVD: `VMWVDPWRPAD-0` (DEV), `VMWVDPWRPAP-0` (PROD)
- ✅ Host Pools: `Hp-wvd-pwrpa-dev-001`, `Hp-wvd-pwrpa-pro-001`
- ✅ Workspaces AVD: `IPE-PRODWARERPADEV`, `IPE-PRODWARERPAPRO`
- ✅ Resource Group: `RG-NorthEurope-IPE-WVD-PWRPA`

### **Recursos a Crear:**
- ⏳ Azure AI Services (AI Foundry) con GPT-5-nano + GPT-5-mini

---

## 🚀 Flujo de Migración (3 Fases)

### **FASE 1: Desplegar Azure AI Foundry en FEMXA** ✅ COMPLETADA

**Estado:** ✅ Desplegado 2026-02-19

**Decisión Arquitectónica:**
- 🌍 **Location: East US 2** (en lugar de North Europe)
- 📌 **Razón:** gpt-5-nano NO disponible en North Europe, solo gpt-5-mini
- 💡 **Trade-off aceptado:** +50ms latencia vs disponibilidad de ambos modelos

**Recurso Desplegado:**

```
Azure AI Services:  openai-ipe-001
Resource Group:     RG-NorthEurope-IPE-WVD-PWRPA
Location:           East US 2
Endpoint:           https://openai-ipe-001.cognitiveservices.azure.com/

Deployments:
  - gpt-5-nano  (GlobalStandard, v2025-08-07, capacity 1)
  - gpt-5-mini  (GlobalStandard, v2025-08-07, capacity 1)
```

**📄 Documentación completa de conexión:**
- Ver: [AI-SERVICES-CONNECTION-INFO.md](docs/AI-SERVICES-CONNECTION-INFO.md)
- Incluye: API key, ejemplos curl, troubleshooting, Power Platform setup

**Archivos Bicep:**
- Template: [`bicep/ai-foundry.bicep`](bicep/ai-foundry.bicep)
- Parameters: [`bicep/ai-foundry.parameters.json`](bicep/ai-foundry.parameters.json)
- Deploy script: [`scripts/deploy-ai-foundry.sh`](scripts/deploy-ai-foundry.sh)

**Pre-requisitos:** ✅ Completados
---

### **FASE 2: Power Platform - Environments y Solución** ⏳ EN PROGRESO

#### **2.1 Crear Entornos en FEMXA** ✅ COMPLETADO

**Estado:** ✅ Environments creados 2026-02-19

- ✅ **IPEDITORIAL-DEV** (Sandbox, Europe, Dataverse, Ready)
- ✅ **IPEDITORIAL-PROD** (Production, Europe, Dataverse, Ready)
- ✅ Creados por: mvallemonjas@femxaformacion.onmicrosoft.com

**URL Maker Portal:** https://make.powerapps.com

#### **2.2 Exportar Solución (Tenant IP Editorial)** ⏳ PENDIENTE

**⚠️ IMPORTANTE:** Esta tarea debe realizarla **Ana Montesinos (Prodware)** o usuario con:
- ✅ Licencia Power Automate Premium
- ✅ Rol System Administrator (sin licencia no aparecen connection references)

**Pasos:**

1. Ir a: https://make.powerapps.com
2. **Tenant:** ipeditorial.onmicrosoft.com (IP Editorial)
3. **Entorno:** IPEditorial-PRO
4. **Solutions** → `IPEditorial-Connections` (v1.0.0.5)
5. **Export** → **Managed Solution** (NO unmanaged)
6. ⏳ Esperar compilación (puede tomar 2-5 minutos)
7. Descargar .zip (ej: `IPEditorial-Connections_1_0_0_5_managed.zip`)
8. **Enviar .zip a Juan/Miguel** por email o SharePoint

#### **2.3 Importar en FEMXA DEV** ⏳ PENDIENTE (requiere .zip de paso 2.2)

1. Ir a: https://make.powerapps.com
2. **Tenant:** femxaformacion.onmicrosoft.com
3. **Entorno:** IPEDITORIAL-DEV
4. **Solutions** → Import solution
5. Seleccionar .zip exportado
6. Next → Configurar connections (ver FASE 3)

---

### **FASE 3: Configurar Connections con Azure AI** ⏳ PENDIENTE

**Pre-requisito:** Fase 2.3 completada (solución importada)

**Dentro de la solución importada en IPEDITORIAL-DEV:**

1. **Connection References** → Azure OpenAI / Cognitive Services Custom Connector
2. **Edit connection** o **Create new connection**:
   ```
   Connection Name:    Azure OpenAI - IPE FEMXA
   Endpoint URL:       https://openai-ipe-001.cognitiveservices.azure.com/
   API Key:            [ver AI-SERVICES-CONNECTION-INFO.md]
   API Version:        2024-02-15-preview (o la que use la solución)
   ```
3. **Save** y **Test connection**
4. **Mapear connection references** en la solución:
   - Durante import, Power Platform detectará connections faltantes
   - Seleccionar la nueva connection creada en paso 2

**Environment Variables a actualizar (si existen):**
```
OPENAI_ENDPOINT:          https://openai-ipe-001.cognitiveservices.azure.com/
OPENAI_DEPLOYMENT_NANO:   gpt-5-nano
OPENAI_DEPLOYMENT_MINI:   gpt-5-mini
OPENAI_API_VERSION:       2024-02-15-preview
```

**📄 Referencia:** Ver guía detallada en [AI-SERVICES-CONNECTION-INFO.md](docs/AI-SERVICES-CONNECTION-INFO.md) sección "Configuración en Power Platform"

---

### **FASE 4: Testing y Validación** ⏳ PENDIENTE

#### **En IPEDITORIAL-DEV:**

1. **Flows** → Seleccionar flujo RPA
2. **Turn on** (activar)
3. **Test** → Manually → Run test
4. Verificar:
   - ✅ Conexión exitosa con Azure OpenAI
   - ✅ Respuestas del modelo GPT
   - ✅ Integración con VMs AVD

#### **Despliegue a PROD:**

Una vez validado en DEV:

1. Exportar solución de IPEDITORIAL-DEV (Managed)
2. Importar en IPEDITORIAL-PROD
3. Reconfigurar connections (mismo endpoint, mismo API key)
4. Asignar licencia **Power Automate Process** al entorno PROD
5. Activar flujos
6. Testing final

---

## 🔐 Seguridad y Permisos

### **Azure RBAC (FEMXA):**

```bash
# Asignar permisos a usuario Ana (si necesario)
az role assignment create \
  --assignee "a.gutierrez@prodware.es" \
  --role "Cognitive Services OpenAI User" \
  --scope "/subscriptions/468c07e9-6936-4ad7-9399-ce402bb0f38a/resourceGroups/RG-NorthEurope-IPE-WVD-PWRPA/providers/Microsoft.CognitiveServices/accounts/openai-ipe-rpa"
```

### **Power Platform Licenses:**

- ✅ Power Automate Premium → Usuario Ana
- ✅ Power Automate Process → Entorno IPEDITORIAL-PROD
- ⚠️ Verificar que licencias están asignadas en tenant FEMXA

---

## 📊 Costos Estimados (Mensual)

| Recurso | Configuración | Costo Aprox. |
|---------|---------------|--------------|
| Azure AI Services S0 | Base | $0/mes |
| GPT-5-nano | 10K TPM | ~$50-100/mes (según uso) |
| GPT-5-mini | 10K TPM | ~$100-150/mes (según uso) |
| Power Automate Process | 1 licencia | Variable (ya comprada) |
| **TOTAL estimado** | | **$150-250/mes** |

*Nota: Costos dependen del volumen de tokens procesados.*

---

## 📞 Contactos

- **Cliente:** Pedro López (plopez@ipeditorial.com) - Director General IP Editorial
- **Partner Infra:** Juan M. Bouzada (jbouzada@asirsl.com) - Administrador Sistemas ASIR
- **Desarrollador:** Ana Gutiérrez Lázaro (a.gutierrez@prodware.es) - Senior Developer Prodware

---

## 📝 Notas Importantes

1. **No se migran las VMs AVD** → Ya existen en FEMXA
2. **No se migran datos Dataverse** → Solo la solución (apps/flows)
3. **Las API Keys del AI Services son sensibles** → Almacenar en Key Vault
4. **Testing obligatorio en DEV** antes de desplegar a PROD
5. **Documentar cambios** en environment variables para troubleshooting

---

## ✅ Checklist de Migración

```
FASE 1: Azure AI Foundry
[ ] Nombre del recurso definido
[ ] Script deploy-ai-foundry.sh actualizado
[ ] Despliegue ejecutado exitosamente
[ ] Endpoint y API Key almacenados

FASE 2: Power Platform
[ ] Solución exportada de IP Editorial-PRO
[ ] Entornos IPEDITORIAL-DEV/PROD creados en FEMXA
[ ] Solución importada en IPEDITORIAL-DEV
[ ] Connections configuradas con nuevo AI Foundry

FASE 3: Validación
[ ] Flujos activados en DEV
[ ] Tests manuales ejecutados
[ ] VMs AVD accesibles desde flujos
[ ] Respuestas GPT verificadas

FASE 4: Producción
[ ] Solución exportada de DEV
[ ] Solución importada en PROD
[ ] Licencia Process asignada
[ ] Flujos activados en PROD
[ ] Smoke tests ejecutados
[ ] Monitoreo configurado
```

---

**Última actualización:** 19 de febrero de 2026  
**Versión:** 1.0
