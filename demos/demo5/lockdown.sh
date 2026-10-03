#!/usr/bin/env bash
# Demo 5: el backend cerrado solo acepta tráfico de APIM. API: /demo5
source "$(dirname "$0")/../../scripts/lib.sh"
load_env

call "1) Backend abierto (demos 1-4), directo -> 200: ¡se salta APIM y todas sus políticas!" \
  "$BACKEND_URL/orders"
pause

call "2) Backend cerrado, directo -> 403 (ingress: solo la IP de APIM)" \
  "$BACKEND_LOCKED_URL/orders"
pause

call "3) Backend cerrado vía APIM (/demo5, Managed Identity) -> 200" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/demo5/orders"
