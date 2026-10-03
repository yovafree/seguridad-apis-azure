#!/usr/bin/env bash
# Comprobación rápida antes de la charla: una llamada "feliz" por demo (todas deben dar 2xx)
# y el backend cerrado directo (debe dar 401/403). Regenera demos/.env con tokens nuevos.
#
# Uso: scripts/check.sh
source "$(dirname "$0")/lib.sh"

"$REPO_ROOT/scripts/export-env.sh"
load_env

KEY=(-H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY")

call "Demo 1: /demo1/orders -> 200" "${KEY[@]}" "$APIM_URL/demo1/orders"
call "Demo 2: /demo2/orders -> 200" "${KEY[@]}" "$APIM_URL/demo2/orders"
call "Demo 3: /demo3/orders con token -> 200" "${KEY[@]}" -H "Authorization: Bearer $TOKEN_READER" "$APIM_URL/demo3/orders"
call "Demo 4: /demo4/orders -> 200" "${KEY[@]}" "$APIM_URL/demo4/orders"
call "Demo 5: /demo5/orders -> 200" "${KEY[@]}" "$APIM_URL/demo5/orders"
call "Demo 5: backend cerrado directo -> 403" "$BACKEND_LOCKED_URL/orders"
