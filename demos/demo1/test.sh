#!/usr/bin/env bash
# Demo 1: APIM como puerta de entrada (subscription key). API: /demo1
source "$(dirname "$0")/../../scripts/lib.sh"
load_env

call "1) Backend directo, sin APIM (cualquiera puede llamarlo) -> 200" \
  "$BACKEND_URL/orders"
pause

call "2) Vía APIM sin subscription key -> 401" \
  "$APIM_URL/demo1/orders"
pause

call "3) Vía APIM con subscription key -> 200" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/demo1/orders"
