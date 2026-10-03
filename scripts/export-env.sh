#!/usr/bin/env bash
# Genera los archivos de entorno de las demos a partir de los outputs de Terraform:
#   demos/.env y demos/demoN/.env -> los usan los scripts y los .http (REST Client: {{$dotenv VAR}})
#
# Incluye tokens de Entra ID (TOKEN_FULL, TOKEN_READER) que duran ~60-90 minutos:
# ejecútalo justo antes de empezar la charla. Todos estos archivos están en .gitignore.

source "$(dirname "$0")/lib.sh"

ensure_azure_login

APIM_URL="$(tf_out apim_url)"
[[ -n "$APIM_URL" ]] || die "No hay outputs de Terraform. Ejecuta primero scripts/deploy.sh"

TOKEN_FULL="$("$REPO_ROOT/scripts/get-token.sh" full 2>/dev/null || true)"
TOKEN_READER="$("$REPO_ROOT/scripts/get-token.sh" reader 2>/dev/null || true)"
[[ -n "$TOKEN_FULL" ]] || warn "No se pudieron obtener tokens (¿permisos en Key Vault?). La Demo 3 los necesita."

ENV_CONTENT="# Generado por scripts/export-env.sh el $(date '+%Y-%m-%d %H:%M'). NO subir a git.
APIM_URL=$APIM_URL
BACKEND_URL=$(tf_out backend_url)
BACKEND_LOCKED_URL=$(tf_out backend_locked_url)
SUBSCRIPTION_KEY=$(tf_out subscription_key)
TOKEN_FULL=$TOKEN_FULL
TOKEN_READER=$TOKEN_READER
RESOURCE_GROUP=$(tf_out resource_group_name)
APIM_NAME=$(tf_out apim_name)
CONTAINER_APP=$(tf_out container_app_name)
LOG_ANALYTICS_WORKSPACE_ID=$(tf_out log_analytics_workspace_id)"

printf '%s\n' "$ENV_CONTENT" >"$DEMOS_DIR/.env"
for dir in "$DEMOS_DIR"/demo*/; do
  printf '%s\n' "$ENV_CONTENT" >"$dir.env"
done
log "Escrito demos/.env (y una copia en cada demos/demoN/ para REST Client)"
