#!/usr/bin/env bash
# Ejecuta desde la terminal la consulta de 429 de la Demo 2 (alternativa al portal).
source "$(dirname "$0")/../../scripts/lib.sh"
ensure_azure_login
load_env

QUERY='ApiManagementGatewayLogs
| where TimeGenerated > ago(30m)
| where ApiId == "orders-demo2"
| summarize total = count(), limitadas = countif(ResponseCode == 429) by bin(TimeGenerated, 1m)
| order by TimeGenerated asc'

log "Llamadas por minuto (últimos 30 min). La ingesta puede tardar 2-5 min."
az monitor log-analytics query \
  --workspace "$LOG_ANALYTICS_WORKSPACE_ID" \
  --analytics-query "$QUERY" \
  --query "[].{minuto:TimeGenerated, total:total, limitadas_429:limitadas}" \
  -o table
