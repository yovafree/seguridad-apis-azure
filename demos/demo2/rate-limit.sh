#!/usr/bin/env bash
# Demo 2: ráfaga de llamadas con curl y conteo de códigos de estado.
# Uso: demos/demo2/rate-limit.sh [demo1|demo2] [cantidad]
#   demo2 (por defecto) -> API con rate limit: 10 x 200 y luego 429
#   demo1               -> "antes": la misma ráfaga contra la API sin límite (todo 200)
source "$(dirname "$0")/../../scripts/lib.sh"
load_env

API="${1:-demo2}"
TOTAL="${2:-15}"
URL="$APIM_URL/$API/orders"
KEY=(-H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY")

declare -i ok=0 throttled=0 other=0

log "Enviando $TOTAL llamadas a $URL"
for ((i = 1; i <= TOTAL; i++)); do
  RESPONSE="$(curl -sS -D - -o /dev/null "${KEY[@]}" "$URL" | tr -d '\r')"
  CODE="$(printf '%s\n' "$RESPONSE" | head -1 | awk '{print $2}')"
  REMAINING="$(printf '%s\n' "$RESPONSE" | sed -n -E 's/^[Xx]-[Rr]ate[Ll]imit-[Rr]emaining: *//p')"
  RETRY="$(printf '%s\n' "$RESPONSE" | sed -n -E 's/^[Rr]etry-[Aa]fter: *//p')"

  case "$CODE" in
    2*) ok+=1; printf '  #%-3s %sHTTP %s%s  restantes: %s\n' "$i" "$C_GREEN" "$CODE" "$C_RESET" "${REMAINING:--}" ;;
    429) throttled+=1; printf '  #%-3s %sHTTP %s%s  Retry-After: %ss\n' "$i" "$C_RED" "$CODE" "$C_RESET" "${RETRY:-?}" ;;
    *) other+=1; printf '  #%-3s %sHTTP %s%s\n' "$i" "$C_YELLOW" "$CODE" "$C_RESET" ;;
  esac
done

log "Resumen"
printf '  2xx: %d\n  429: %d\n  otros: %d\n' "$ok" "$throttled" "$other"

if (( throttled > 0 )); then
  call "Detalle de una respuesta 429 (ProblemDetails)" -i "${KEY[@]}" "$URL"
fi
