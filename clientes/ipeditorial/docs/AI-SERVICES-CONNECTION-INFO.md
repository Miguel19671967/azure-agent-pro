# Azure AI Services - Configuración para Power Platform
**Cliente:** IP Editorial / FEMXA  
**Fecha deployment:** 2026-02-19  
**Tenant:** FEMXA (efbe317b-6cdb-46bd-82a7-d5fa8fbcb7e4)

---

## 📋 Información de Conexión

### Azure AI Services Resource
| Parámetro | Valor |
|-----------|-------|
| **Resource Name** | `openai-ipe-001` |
| **Resource Group** | `RG-NorthEurope-IPE-WVD-PWRPA` |
| **Subscription** | Microsoft Azure (femxaformacion): #1003512 |
| **Location** | East US 2 |
| **Resource ID** | `/subscriptions/468c07e9-6936-4ad7-9399-ce402bb0f38a/resourceGroups/RG-NorthEurope-IPE-WVD-PWRPA/providers/Microsoft.CognitiveServices/accounts/openai-ipe-001` |

### Endpoint & Authentication
```
Endpoint:  https://openai-ipe-001.cognitiveservices.azure.com/
API Key:   ac1bb315bfa546628c36cd259bcf12d9
```

### Model Deployments
| Deployment Name | Model | Version | SKU | Capacidad |
|----------------|-------|---------|-----|-----------|
| `gpt-5-nano` | gpt-5-nano | 2025-08-07 | GlobalStandard | 1 unit |
| `gpt-5-mini` | gpt-5-mini | 2025-08-07 | GlobalStandard | 1 unit |

---

## 🔌 Configuración en Power Platform

### 1. Crear Custom Connector (si no existe)

En el **Power Apps Maker Portal** (https://make.powerapps.com):

1. Navega al environment **IPEDITORIAL-DEV** o **IPEDITORIAL-PROD**
2. Ve a **Data > Custom Connectors**
3. Crea un nuevo connector:
   - **Connector Type:** OpenAPI from blank
   - **Connector Name:** Azure OpenAI IPE
   - **Host:** `openai-ipe-001.cognitiveservices.azure.com`
   - **Base URL:** `/`

4. **Security**:
   - **Authentication type:** API Key
   - **Parameter label:** api-key
   - **Parameter name:** api-key
   - **Parameter location:** Header

5. **Definition** - Añadir actions:
   
   **Action: Chat Completion**
   - **Request verb:** POST
   - **URL:** `/openai/deployments/{deployment-id}/chat/completions?api-version=2024-02-15-preview`
   - **Headers:**
     - `Content-Type: application/json`
     - `api-key: {api-key}`
   - **Body (Schema):**
     ```json
     {
       "messages": [
         {"role": "system", "content": "You are a helpful assistant."},
         {"role": "user", "content": "Hello"}
       ],
       "max_completion_tokens": 800,
       "temperature": 0.7
     }
     ```

### 2. Crear Connection

1. Ve a **Data > Connections**
2. Crea nueva connection usando el Custom Connector **Azure OpenAI IPE**
3. Introduce el API Key cuando se solicite: `ac1bb315bfa546628c36cd259bcf12d9`
4. **Nombre de la conexión:** `Azure OpenAI IPE - Production` (o DEV según el environment)

### 3. Actualizar Connection References en la Solución

Cuando importes la solución **IPEditorial-Connections** desde el tenant origen:

1. Durante la importación, Power Platform te pedirá configurar Connection References
2. Mapea la connection reference antigua a la nueva:
   - **Connection Reference Name:** (el que tenga la solución exportada)
   - **Nueva Connection:** Selecciona `Azure OpenAI IPE - Production`

### 4. Actualizar Deployment Names en Flows

Si los flows referencian deployment names específicos, actualiza las llamadas:

**Origen (IP Editorial):**
- Deployment gpt-5-nano: probablemente el mismo nombre
- Deployment gpt-5-mini: probablemente el mismo nombre

**Destino (FEMXA):**
- Deployment gpt-5-nano: `gpt-5-nano`
- Deployment gpt-5-mini: `gpt-5-mini`

**Ejemplo de llamada actualizada:**
```
POST https://openai-ipe-001.cognitiveservices.azure.com/openai/deployments/gpt-5-nano/chat/completions?api-version=2024-02-15-preview

Headers:
  api-key: ac1bb315bfa546628c36cd259bcf12d9
  Content-Type: application/json

Body:
{
  "messages": [
    {"role": "system", "content": "Eres un asistente para procesos RPA"},
    {"role": "user", "content": "{input_texto}"}
  ],
  "max_completion_tokens": 500
}
```

---

## 🔐 Seguridad y Best Practices

### ⚠️ IMPORTANTE: Gestión de Secretos

**Estado Actual:**
- ✅ API Key funcional: `ac1bb315bfa546628c36cd259bcf12d9`
- ❌ No hay Key Vault configurado en RG-NorthEurope-IPE-WVD-PWRPA

**Recomendaciones:**

1. **Crear Azure Key Vault** (OPCIONAL pero recomendado para producción):
   ```bash
   az keyvault create \
     --name "kv-ipe-pwrpa-001" \
     --resource-group "RG-NorthEurope-IPE-WVD-PWRPA" \
     --location "northeurope" \
     --enable-rbac-authorization false
   
   az keyvault secret set \
     --vault-name "kv-ipe-pwrpa-001" \
     --name "openai-api-key" \
     --value "ac1bb315bfa546628c36cd259bcf12d9"
   ```

2. **Regenerar API Key Periódicamente:**
   ```bash
   az cognitiveservices account keys regenerate \
     --name "openai-ipe-001" \
     --resource-group "RG-NorthEurope-IPE-WVD-PWRPA" \
     --key-name key1
   ```

3. **Usar Managed Identities** (avanzado):
   - Configurar Power Automate con Managed Identity
   - Asignar rol `Cognitive Services User` al identity
   - Eliminar API keys de connections

### Network Security

**Estado actual:**
- ✅ Public Network Access: Enabled (necesario para Power Platform Cloud)
- ℹ️ Si se requiere mayor seguridad:
  - Configurar Private Endpoint en VNet AVD
  - Usar hybrid connections desde Power Automate on-premises gateway

### Monitoring & Costs

**Monitoreo:**
```bash
# Ver métricas de uso
az monitor metrics list \
  --resource "/subscriptions/468c07e9-6936-4ad7-9399-ce402bb0f38a/resourceGroups/RG-NorthEurope-IPE-WVD-PWRPA/providers/Microsoft.CognitiveServices/accounts/openai-ipe-001" \
  --metric "TotalTokens" \
  --aggregation Total

# Ver logs (si diagnostic settings configurado)
az monitor log-analytics query \
  --workspace <LOG_ANALYTICS_WORKSPACE_ID> \
  --analytics-query "AzureDiagnostics | where ResourceType == 'ACCOUNTS' and ResourceProvider == 'MICROSOFT.COGNITIVESERVICES'"
```

**Costos estimados:**
- **SKU S0 AI Services:** ~$0/mes (solo pagas por uso de tokens)
- **GPT-5-nano (GlobalStandard, capacity=1):** ~$X/mes + $Y por 1M tokens
- **GPT-5-mini (GlobalStandard, capacity=1):** ~$X/mes + $Z por 1M tokens

Ver pricing actualizado: https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/

---

## 📊 Testing & Validation

### Prueba rápida con curl:

```bash
curl -X POST "https://openai-ipe-001.cognitiveservices.azure.com/openai/deployments/gpt-5-nano/chat/completions?api-version=2024-02-15-preview" \
  -H "Content-Type: application/json" \
  -H "api-key: ac1bb315bfa546628c36cd259bcf12d9" \
  -d '{
    "messages": [
      {"role": "system", "content": "Eres un asistente útil."},
      {"role": "user", "content": "Hola, ¿funcionas correctamente?"}
    ],
    "max_completion_tokens": 100
  }'
```

**Respuesta esperada:**
```json
{
  "id": "chatcmpl-xxxxx",
  "object": "chat.completion",
  "created": 1708358400,
  "model": "gpt-5-nano",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "¡Sí, funciono correctamente! ¿En qué puedo ayudarte?"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 25,
    "completion_tokens": 15,
    "total_tokens": 40
  }
}
```

---

## 🚨 Troubleshooting

### Error: "Unauthorized" (401)
- ✅ Verifica que el API key es correcto
- ✅ Verifica que el header es `api-key` (no `Api-Key` ni `Authorization`)

### Error: "Model not found" (404)
- ✅ Verifica que el deployment name es exacto: `gpt-5-nano` o `gpt-5-mini`
- ✅ Verifica que la URL incluye `/openai/deployments/{deployment-name}/...`

### Error: "Quota exceeded" (429)
- ℹ️ Has alcanzado el límite de capacity (1 unit)
- 💡 Solución: Incrementar capacity en Bicep y re-deploy, o esperar reset de cuota

### Latencia alta
- ℹ️ El servicio está en **East US 2** (no North Europe)
- ℹ️ Latencia típica desde Europa: ~60-80ms adicionales vs North Europe
- 💡 Para workloads críticos de latencia, valorar cambio a gpt-5-mini solo en North Europe

---

## 📞 Contactos

**Infraestructura Azure:**
- Juan (ASIR): jbouz@asir.es

**Desarrollo Power Platform:**
- Ana (Prodware): amontesinos@prodware.es

**Azure Architect Pro:**
- Documentación generada automáticamente por agente IA
- Fecha: 2026-02-19

---

**Siguiente paso:** Exportar solución IPEditorial-Connections desde tenant IP Editorial e importar a IPEDITORIAL-DEV en FEMXA.
