# 📊 Queries KQL para Application Insights - Kitten Space Missions

## 📌 Queries Esenciales

### 1. Request Rate (Requests per Minute - últimas 24h)

```kql
requests
| where timestamp > ago(24h)
| summarize RequestCount = count() by bin(timestamp, 5m)
| render timechart 
```

### 2. Response Time P95 por Endpoint

```kql
requests
| where timestamp > ago(1h)
| summarize p95_duration = percentile(duration, 95) by name
| order by p95_duration desc
| render barchart
```

### 3. Error Rate (HTTP 5xx)

```kql
requests
| where timestamp > ago(1h)
| summarize TotalRequests = count(), 
            FailedRequests = countif(success == false)
| extend ErrorRate = (FailedRequests * 100.0) / TotalRequests
| project ErrorRate, TotalRequests, FailedRequests
```

### 4. Top 10 Endpoints Más Lentos

```kql
requests
| where timestamp > ago(24h)
| summarize avg_duration = avg(duration), p99_duration = percentile(duration, 99), count = count() by name
| order by avg_duration desc
| take 10
| render table
```

### 5. Failed Requests con Detalles

```kql
requests
| where timestamp > ago(1h) and success == false
| project timestamp, name, resultCode, duration, url, customDimensions
| order by timestamp desc
| take 100
```

### 6. Dependency Calls (SQL, Key Vault, External APIs)

```kql
dependencies
| where timestamp > ago(1h)
| summarize count(), avg(duration), max(duration), p95 = percentile(duration, 95) by name, type
| order by avg_duration desc
| render table
```

### 7. Slow SQL Queries (> 1 segundo)

```kql
dependencies
| where type == "SQL"
| where duration > 1000  // > 1 segundo
| project timestamp, name, duration, success, target
| order by timestamp desc
| take 50
```

### 8. Key Vault Access Patterns

```kql
dependencies
| where type == "Azure key vault"
| where timestamp > ago(24h)
| summarize AccessCount = count(), AvgDuration = avg(duration) by name
| order by AccessCount desc
```

### 9. Exceptions y Errores

```kql
exceptions
| where timestamp > ago(24h)
| summarize count() by type, outerMessage
| order by count_ desc
| take 20
```

### 10. Availability Percentage (últimas 24h)

```kql
requests
| where timestamp > ago(24h)
| summarize SuccessfulRequests = countif(success == true), TotalRequests = count()
| extend AvailabilityPercent = (SuccessfulRequests * 100.0) / TotalRequests
| project AvailabilityPercent, SuccessfulRequests, TotalRequests
```

### 11. Request Distribution by HTTP Method

```kql
requests
| where timestamp > ago(1h)
| summarize count() by httpMethod = tostring(customDimensions.HttpMethod)
| render piechart
```

### 12. Geographic Distribution (if enabled)

```kql
requests
| where timestamp > ago(24h)
| summarize count() by client_City, client_CountryOrRegion
| order by count_ desc
| take 10
```

---

## 🎯 SRE Golden Signals Queries

### Latency (Response Time)

```kql
requests
| where timestamp > ago(1h)
| summarize p50 = percentile(duration, 50), 
            p95 = percentile(duration, 95), 
            p99 = percentile(duration, 99) 
by bin(timestamp, 5m)
| render timechart
```

### Traffic (Requests Per Second)

```kql
requests
| where timestamp > ago(1h)
| summarize RequestsPerSecond = count() / 60.0 by bin(timestamp, 1m)
| render timechart
```

### Errors (Error Rate %)

```kql
requests
| where timestamp > ago(1h)
| summarize ErrorRate = (countif(success == false) * 100.0) / count() by bin(timestamp, 5m)
| render timechart
```

### Saturation (Database DTU usage - requiere metrics)

```kql
// Query metrics de Azure SQL Database DTU
// Nota: Esto requiere acceso a metrics, no está en Application Insights por defecto
```

---

## 🔧 Troubleshooting Queries

### Requests con Alta Latencia (> 5 segundos)

```kql
requests
| where timestamp > ago(1h)
| where duration > 5000
| project timestamp, name, duration, resultCode, url, operation_Id
| order by duration desc
| take 50
```

### Failed Dependencies (External Calls)

```kql
dependencies
| where timestamp > ago(1h) and success == false
| project timestamp, type, name, target, duration, resultCode
| order by timestamp desc
```

### User Sessions con Errores

```kql
requests
| where timestamp > ago(1h) and success == false
| summarize ErrorCount = count() by session_Id, user_Id
| order by ErrorCount desc
| take 20
```

---

## 📊 Dashboard Recommendations

Para crear un dashboard en Azure Portal:

1. **Overview Tile**: Request rate (línea de tiempo - últimas 24h)
2. **Latency Tile**: P95 duration gauge (meta: < 500ms)
3. **Error Rate Tile**: Big number (meta: < 1%)
4. **Availability Tile**: Percentage big number (meta: > 99.5%)
5. **Failed Requests**: Table con detalles
6. **Dependency Performance**: Bar chart (SQL, Key Vault, etc.)

---

## 🚨 Alertas Recomendadas (ya desplegadas en Bicep)

Las siguientes alertas están configuradas en el módulo `monitoring.bicep`:

1. **High Error Rate**: HTTP 5xx > 10 en 5 minutos → Severity 0 (Critical)
2. **High Latency**: P95 > 1000ms por 10 minutos → Severity 2 (Warning)

Alertas adicionales a considerar:

3. **Low Availability**: < 99% disponibilidad en 15 minutos
4. **High SQL DTU**: DTU usage > 80% por 10 minutos
5. **Dependency Failures**: > 5 failed dependencies en 5 minutos

---

## 📚 Referencias

- [KQL Quick Reference](https://learn.microsoft.com/azure/data-explorer/kql-quick-reference)
- [Application Insights Query Examples](https://learn.microsoft.com/azure/azure-monitor/logs/examples)
- [SRE Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/)
