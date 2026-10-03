#!/usr/bin/env bash
# Ejecuta la prueba de carga k6 contra /demo2 con las variables de demos/.env.
source "$(dirname "$0")/../../scripts/lib.sh"
require k6 "Instala k6: https://grafana.com/docs/k6/latest/set-up/install-k6/"
load_env

k6 run \
  -e API_URL="$APIM_URL/demo2" \
  -e SUBSCRIPTION_KEY="$SUBSCRIPTION_KEY" \
  "$(dirname "$0")/rate-limit.k6.js"
