#!/bin/bash
# Test Azure AI Services deployment
# Cliente: IP Editorial / FEMXA

ENDPOINT="https://openai-ipe-001.cognitiveservices.azure.com"
API_KEY="ac1bb315bfa546628c36cd259bcf12d9"
DEPLOYMENT="gpt-5-nano"

echo "🧪 Testing Azure AI Services: openai-ipe-001"
echo "Endpoint: $ENDPOINT"
echo "Deployment: $DEPLOYMENT"
echo ""

curl -X POST "$ENDPOINT/openai/deployments/$DEPLOYMENT/chat/completions?api-version=2024-02-15-preview" \
  -H "Content-Type: application/json" \
  -H "api-key: $API_KEY" \
  -d '{
    "messages": [
      {"role": "system", "content": "Eres un asistente RPA para IP Editorial."},
      {"role": "user", "content": "Test de conectividad. ¿Estás operativo?"}
    ],
    "max_completion_tokens": 50
  }' | jq .

echo ""
echo "✅ Si ves una respuesta JSON con 'choices[0].message.content', el servicio está operativo."
