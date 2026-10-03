#!/usr/bin/env bash
# Demo 4: validación contra el esquema OpenAPI y limpieza de headers.
# Compara la MISMA llamada en /demo1 (sin validación) y en /demo4 (con validación).
source "$(dirname "$0")/../../scripts/lib.sh"
load_env

KEY=(-H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY")
JSON=(-H "Content-Type: application/json")
EXTRA='{"customerId":"cliente-300","product":"Silla","quantity":1,"unitPrice":120.00,"isAdmin":true}'
QTY_500='{"customerId":"cliente-300","product":"Silla","quantity":500,"unitPrice":120.00}'

log "A) Headers de respuesta: ¿se ve la tecnología del backend?"
headers "Vía /demo1 (sin limpieza)" "${KEY[@]}" "$APIM_URL/demo1/orders"
headers "Vía /demo4 (con limpieza)" "${KEY[@]}" "$APIM_URL/demo4/orders"
pause

log "B) Campo extra no declarado (\"isAdmin\": true)"
call "Vía /demo1 -> 201 (¡el backend lo acepta sin quejarse!)" \
  "${KEY[@]}" "${JSON[@]}" -X POST -d "$EXTRA" "$APIM_URL/demo1/orders"
call "Vía /demo4 -> 400 (lo rechaza APIM: el backend nunca lo ve)" \
  "${KEY[@]}" "${JSON[@]}" -X POST -d "$EXTRA" "$APIM_URL/demo4/orders"
pause

log "C) quantity = 500 (el esquema permite 1-100)"
call "Vía /demo4 -> 400 (el rango sale de [Range(1, 100)] en el código .NET)" \
  "${KEY[@]}" "${JSON[@]}" -X POST -d "$QTY_500" "$APIM_URL/demo4/orders"
