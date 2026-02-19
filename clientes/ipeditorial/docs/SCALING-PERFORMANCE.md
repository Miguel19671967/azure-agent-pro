# Scaling & Performance - Azure AI Services

**Recurso:** openai-ipe-001  
**Cliente:** IP Editorial / FEMXA  
**Fecha:** 2026-02-19

---

## ⚡ Estado Actual del Deployment (Baseline)

### Configuración Deploy Inicial
```
SKU Account:            S0 (Standard)
Deployment gpt-5-nano:  GlobalStandard, capacity 1
Deployment gpt-5-mini:  GlobalStandard, capacity 1
```

### Rate Limits Observados (SKU S0, capacity 1)

Durante testing detectamos:
```
❌ Error: RateLimitReached
Message: "Your requests to gpt-5-nano for gpt-5-nano in East US 2 have 
         exceeded the call rate limit for your current AIServices S0 pricing tier."
Retry-After: 15-35 seconds
```

**Implicaciones:**
- ⚠️ **Muy bajo throughput** para workloads de producción
- ⚠️ Apropiado SOLO para **DEV/POC** con tráfico mínimo
- ✅ Production RPA requiere **incrementar capacity**

---

## 📊 Capacity Planning

### Estimación de Carga (Completar con datos reales)

**Preguntas a responder con el equipo Power Platform:**

1. **Volumen esperado de llamadas RPA:**
   - ¿Cuántos procesos RPA ejecutan diariamente?
   - ¿Cuántas llamadas a GPT hace cada proceso?
   - **Estimación total llamadas/día:** _____

2. **Patrón de uso:**
   - ¿Concurrencia esperada? (llamadas simultáneas) _____
   - ¿Picos de carga en horarios específicos? _____

3. **Latencia aceptable:**
   - ¿RTT máximo aceptable end-to-end? _____ ms
   - ¿Timeout configurado en Power Automate? _____ segundos

4. **Tamaño de requests:**
   - Promedio tokens por prompt: _____
   - Promedio tokens por completion: _____

---

## 🚀 Opciones de Scaling

### Opción 1: Incrementar Capacity Deployment (Recomendado)

**Actualizar Bicep:**
```bicep
// bicep/ai-foundry.bicep

resource gpt5NanoDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: aiServices
  name: 'gpt-5-nano'
  sku: {
    name: 'GlobalStandard'
    capacity: 10 // ⬆️ Incrementar de 1 a 10+
  }
  ...
}
```

**Redeploy:**
```bash
cd /home/mvallemonjas/azure-agent-pro/clientes/ipeditorial

# Actualizar capacity en bicep/ai-foundry.parameters.json o directamente en .bicep
nano bicep/ai-foundry.bicep

# Re-deploy
az deployment group create \
  --name "ai-foundry-ipe-scale-$(date +%Y%m%d-%H%M%S)" \
  --resource-group "RG-NorthEurope-IPE-WVD-PWRPA" \
  --template-file "bicep/ai-foundry.bicep" \
  --parameters "@bicep/ai-foundry.parameters.json"
```

**Guía de Capacity según carga:**

| Llamadas/día | Concurrencia | Capacity Recomendado | Costo Estimado* |
|--------------|--------------|----------------------|-----------------|
| < 1,000 | 1-2 | 1 | $XX/mes |
| 1,000 - 10,000 | 2-5 | 5-10 | $XXX/mes |
| 10,000 - 100,000 | 5-20 | 10-50 | $X,XXX/mes |
| > 100,000 | 20+ | 50-100+ | $XX,XXX/mes |

*Verificar pricing actual: https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/

---

### Opción 2: Upgrade SKU Account (Para muy alta carga)

Si se requiere throughput enterprise masivo:

```bicep
resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: aiServicesName
  sku: {
    name: 'S'  // Enterprise tier (contactar Azure Sales)
  }
  ...
}
```

**Comparativa SKU:**

| Tier | Límite Base | Incrementable | Uso Típico |
|------|-------------|---------------|------------|
| **S0** | Rate limit bajo | Sí (via capacity) | Dev/Test, Prod ligero |
| **S** | Sin rate limit* | N/A | Enterprise alto volumen |

*Sujeto a quotas de subscription

---

### Opción 3: Multi-Region Load Balancing (Avanzado)

Si latencia East US 2 → Europa es problemática Y se requiere alta disponibilidad:

**Arquitectura:**
```
┌─────────────────┐
│ Power Automate  │
│   (FEMXA EU)    │
└────────┬────────┘
         │
    ┌────▼────┐
    │ Traffic │
    │ Manager │  (geo-routing)
    └────┬────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼───┐
│ AI-EU │ │AI-US2│
│ (mini)│ │(both)│
└───────┘ └──────┘
```

**Consideraciones:**
- ✅ Latencia mínima desde Europa para gpt-5-mini
- ✅ Failover automático si región primaria cae
- ❌ Complejidad gestión doble
- ❌ Costo duplicado infraestructura
- ❌ Power Platform necesita lógica retry con endpoint secundario

---

## 🔍 Monitoring & Alerting

### Métricas Clave a Monitorizar

**Azure Monitor Metrics:**
```bash
# Total requests
az monitor metrics list \
  --resource "/subscriptions/468c07e9-6936-4ad7-9399-ce402bb0f38a/resourceGroups/RG-NorthEurope-IPE-WVD-PWRPA/providers/Microsoft.CognitiveServices/accounts/openai-ipe-001" \
  --metric "TotalCalls" \
  --aggregation Total \
  --interval PT1H

# Rate limit errors (429)
az monitor metrics list \
  --resource <resource-id> \
  --metric "TotalErrors" \
  --filter "ErrorCode eq '429'" \
  --aggregation Total

# Latency p95
az monitor metrics list \
  --resource <resource-id> \
  --metric "Latency" \
  --aggregation percentile_95
```

### Alertas Recomendadas

**Alert 1: Rate Limit Threshold**
```bash
az monitor metrics alert create \
  --name "alert-openai-ipe-ratelimit" \
  --resource-group "RG-NorthEurope-IPE-WVD-PWRPA" \
  --scopes "/subscriptions/.../openai-ipe-001" \
  --condition "count TotalErrors where ErrorCode == 429 > 10" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action-group <action-group-id> \
  --description "Azure OpenAI rate limit alcanzado >10 veces en 5min"
```

**Alert 2: High Latency**
```bash
az monitor metrics alert create \
  --name "alert-openai-ipe-latency" \
  --resource-group "RG-NorthEurope-IPE-WVD-PWRPA" \
  --scopes "/subscriptions/.../openai-ipe-001" \
  --condition "avg Latency > 2000" \
  --window-size 5m \
  --description "Latencia promedio >2s"
```

---

## 💰 Cost Optimization

### Estrategias de Ahorro

1. **Sizing correcto inicial:**
   - Empezar con capacity bajo en DEV
   - Monitorizar 1-2 semanas en DEV
   - Escalar en PROD basándose en datos reales

2. **Auto-scaling (si disponible en futuro):**
   - Azure actualmente NO soporta auto-scale de AI Services deployments
   - Requiere manual capacity adjustment vía Bicep redeploy

3. **Caching en Power Automate:**
   - Cachear respuestas GPT repetitivas (ej: templates comunes)
   - Reducir llamadas duplicadas

4. **Prompt optimization:**
   - Prompts más concisos = menos tokens = menos costo
   - Evitar incluir contexto innecesario en system messages

---

## 📞 Escalado en Producción - Checklist

Antes de Go-Live en IPEDITORIAL-PROD:

- [ ] **Baseline DEV completado** (1-2 semanas testing)
- [ ] **Métricas reales capturadas:**
  - Promedio llamadas/día: _____
  - Promedio tokens/request: _____
  - Picos concurrencia: _____
- [ ] **Capacity calculado** según tabla guía
- [ ] **Bicep actualizado** con nuevo capacity
- [ ] **Re-deploy ejecutado** en PROD
- [ ] **Alertas configuradas** (rate limit, latency)
- [ ] **Presupuesto ajustado** según nueva capacity
- [ ] **Runbook documentado** para scale-up manual si needed

---

## 🚨 Troubleshooting Rate Limits

### Si en Producción se alcanzan rate limits:

**Síntomas:**
- Flows Power Automate fallan con HTTP 429
- Mensajes "Rate limit exceeded" en logs
- Latencias errática (retry delays)

**Solución Inmediata (Emergency):**
```bash
# Incrementar capacity temporalmente
az cognitiveservices account deployment update \
  --name "openai-ipe-001" \
  --resource-group "RG-NorthEurope-IPE-WVD-PWRPA" \
  --deployment-name "gpt-5-nano" \
  --sku-capacity 20  # Duplicar capacity actual
```

**Solución Permanente:**
1. Analizar patrones de uso (Azure Monitor)
2. Ajustar capacity basado en p95 de carga
3. Actualizar Bicep template
4. Re-deploy via CI/CD (GitHub Actions)

---

**Última actualización:** 2026-02-19  
**Contacto Infraestructura:** jbouz@asir.es  
**Azure Architect Pro:** Documentación auto-generada
