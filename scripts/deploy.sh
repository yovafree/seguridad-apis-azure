#!/usr/bin/env bash
# Despliegue completo:
#   1. terraform init
#   2. Resource group + Azure Container Registry (apply con -target)
#   3. Build y publicación de la imagen orders-api en ACR
#   4. terraform plan + apply de todo con environments/demo.tfvars
#   5. Genera demos/.env para las demos
#
# Despliega TODAS las demos a la vez (una API de APIM por demo): durante la charla no hay
# que volver a ejecutar Terraform.
#
# Uso:  scripts/deploy.sh
#       BUILD_MODE=docker scripts/deploy.sh   # build local con Docker (si ACR Tasks no está disponible)
#
# IMPORTANTE: el primer despliegue de APIM (tier Developer) tarda 30-60 minutos.
# Hazlo el día anterior a la charla.

source "$(dirname "$0")/lib.sh"

check_terraform_version
ensure_azure_login

load_var_files
IMAGE_TAG="$(tfvars_value api_image_tag)"
IMAGE_TAG="${IMAGE_TAG:-1.0.0}"

log "Suscripción: $(az account show --query name -o tsv | tr -d '\r') ($ARM_SUBSCRIPTION_ID)"

log "1/5 terraform init"
tf init -input=false

log "2/5 Resource group + Container Registry"
tf apply -input=false -auto-approve "${VAR_FILES[@]}" \
  -target=azurerm_resource_group.this \
  -target=azurerm_container_registry.this

ACR_NAME="$(tf_out acr_name)"
ACR_LOGIN_SERVER="$(tf_out acr_login_server)"
[[ -n "$ACR_NAME" ]] || die "No se pudo leer el nombre del ACR desde los outputs."

log "3/5 Imagen orders-api:$IMAGE_TAG -> $ACR_LOGIN_SERVER"
if [[ "${BUILD_MODE:-acr}" == "docker" ]]; then
  require docker
  az acr login --name "$ACR_NAME"
  docker build -t "$ACR_LOGIN_SERVER/orders-api:$IMAGE_TAG" "$REPO_ROOT/src/Orders.Api"
  docker push "$ACR_LOGIN_SERVER/orders-api:$IMAGE_TAG"
else
  # Build en la nube con ACR Tasks: no necesita Docker local.
  az acr build --registry "$ACR_NAME" --image "orders-api:$IMAGE_TAG" "$REPO_ROOT/src/Orders.Api" \
    || die "Falló 'az acr build'. Si tu suscripción no permite ACR Tasks, usa: BUILD_MODE=docker scripts/deploy.sh"
fi

log "4/5 terraform plan + apply (APIM Developer: 30-60 min la primera vez)"
tf plan -input=false "${VAR_FILES[@]}" -out=tfplan
tf apply -input=false tfplan
rm -f "$INFRA_DIR/tfplan"

log "5/5 Variables para las demos"
"$REPO_ROOT/scripts/export-env.sh"

log "Listo"
printf '  APIM:            %s/<demo1..demo5>/orders\n' "$(tf_out apim_url)"
printf '  Backend abierto: %s\n' "$(tf_out backend_url)"
printf '  Backend cerrado: %s\n' "$(tf_out backend_locked_url)"
printf '  Comprobación:    scripts/check.sh\n'
