#!/usr/bin/env bash
# Demo 3: autenticación y autorización con tokens de Microsoft Entra ID. API: /demo3
# Pide tokens frescos (client credentials) leyendo los outputs de Terraform y Key Vault.
source "$(dirname "$0")/../../scripts/lib.sh"
load_env

URL="$APIM_URL/demo3/orders"
KEY=(-H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY")
JSON=(-H "Content-Type: application/json")
BODY='{"customerId":"cliente-200","product":"Webcam","quantity":1,"unitPrice":45.00}'

log "Obteniendo tokens de Entra ID (client credentials)"
TOKEN_FULL="$("$REPO_ROOT/scripts/get-token.sh" full)"
TOKEN_READER="$("$REPO_ROOT/scripts/get-token.sh" reader)"

call "1) Sin token -> 401" \
  "${KEY[@]}" "$URL"
pause

call "2) Cliente 'reader' lee (tiene Orders.Read) -> 200" \
  "${KEY[@]}" -H "Authorization: Bearer $TOKEN_READER" "$URL"
pause

call "3) Cliente 'reader' intenta crear (requiere Orders.Write) -> 403" \
  "${KEY[@]}" "${JSON[@]}" -H "Authorization: Bearer $TOKEN_READER" -X POST -d "$BODY" "$URL"
pause

call "4) Cliente 'full' crea (tiene Orders.Write) -> 201" \
  "${KEY[@]}" "${JSON[@]}" -H "Authorization: Bearer $TOKEN_FULL" -X POST -d "$BODY" "$URL"
