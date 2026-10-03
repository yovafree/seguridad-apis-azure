#!/usr/bin/env bash
# Obtiene un access token de Entra ID con client credentials.
#
# Uso:  scripts/get-token.sh [full|reader] [--decode]
#   full    -> cliente con roles Orders.Read y Orders.Write (por defecto)
#   reader  -> cliente solo con Orders.Read (POST/DELETE darán 403 en la Demo 3)
#   --decode muestra los claims del token en lugar del token
#
# Lee tenant, client id y scope de los outputs de Terraform, y el client secret desde
# Key Vault (nunca desde el estado ni desde outputs). Requiere `az login`.

source "$(dirname "$0")/lib.sh"

CLIENT="${1:-full}"
[[ "$CLIENT" == "full" || "$CLIENT" == "reader" ]] || die "Cliente inválido: $CLIENT (usa full o reader)"

ensure_azure_login

TENANT_ID="$(tf_out tenant_id)"
CLIENT_ID="$(tf_out "client_${CLIENT}_id")"
SCOPE="$(tf_out api_scope)"
KEY_VAULT="$(tf_out key_vault_name)"
[[ -n "$TENANT_ID" && -n "$CLIENT_ID" ]] || die "Faltan outputs de Terraform. ¿Ejecutaste scripts/deploy.sh?"

CLIENT_SECRET="$(az keyvault secret show --vault-name "$KEY_VAULT" --name "client-${CLIENT}-secret" \
  --query value -o tsv | tr -d '\r')"

RESPONSE="$(curl -sS -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret=$CLIENT_SECRET" \
  --data-urlencode "scope=$SCOPE")"

TOKEN="$(printf '%s' "$RESPONSE" | sed -n -E 's/.*"access_token":"([^"]+)".*/\1/p')"
[[ -n "$TOKEN" ]] || die "No se obtuvo token. Respuesta de Entra ID: $RESPONSE"

if [[ "${2:-}" == "--decode" ]]; then
  # Payload del JWT (base64url -> base64), solo para mostrar los claims en la charla.
  PAYLOAD="$(printf '%s' "$TOKEN" | cut -d. -f2 | tr '_-' '/+')"
  while (( ${#PAYLOAD} % 4 )); do PAYLOAD+="="; done
  printf '%s' "$PAYLOAD" | base64 -d 2>/dev/null | sed -E 's/,"/,\n  "/g; s/^\{/{\n  /; s/\}$/\n}/'
  echo
else
  printf '%s\n' "$TOKEN"
fi
