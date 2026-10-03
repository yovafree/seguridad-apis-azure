#!/usr/bin/env bash
# Elimina todos los recursos de la demo (Azure + app registrations de Entra ID).
# Uso: scripts/destroy.sh
source "$(dirname "$0")/lib.sh"

check_terraform_version
ensure_azure_login

warn "Se eliminarán TODOS los recursos de la demo y las app registrations."
load_var_files
tf destroy -input=false "${VAR_FILES[@]}"

rm -f "$DEMOS_DIR/.env" "$DEMOS_DIR"/demo*/.env
log "Listo. Archivos locales de entorno eliminados."
