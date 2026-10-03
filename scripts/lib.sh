#!/usr/bin/env bash
# Funciones comunes para los scripts del repo. Se usa con: source "$(dirname "$0")/lib.sh"
# Funciona en Linux, macOS, WSL y Git Bash (Windows). No requiere jq.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$REPO_ROOT/infra"
DEMOS_DIR="$REPO_ROOT/demos"
TFVARS_FILE="environments/demo.tfvars"
TF="${TF:-terraform}"

# --- Salida -----------------------------------------------------------------

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_CYAN=$'\033[1;36m'
  C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'
else
  C_RESET=""; C_BOLD=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi

log()  { printf '\n%s==> %s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
warn() { printf '%sAviso: %s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }
die()  { printf '%sError: %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

# --- Prerrequisitos ---------------------------------------------------------

require() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontró '$1' en el PATH. ${2:-}"
}

check_terraform_version() {
  require "$TF" "Instala Terraform >= 1.11: https://developer.hashicorp.com/terraform/install"
  local version major minor
  version="$("$TF" version | head -1 | sed -E 's/^Terraform v([0-9]+)\.([0-9]+).*/\1 \2/')"
  read -r major minor <<<"$version"
  if (( major < 1 || (major == 1 && minor < 11) )); then
    die "Se requiere Terraform >= 1.11 (encontrado: $("$TF" version | head -1))."
  fi
}

ensure_azure_login() {
  require az "Instala Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"
  az account show >/dev/null 2>&1 || die "No hay sesión de Azure CLI. Ejecuta: az login"
  ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-$(az account show --query id -o tsv | tr -d '\r')}"
  export ARM_SUBSCRIPTION_ID
}

# --- Terraform --------------------------------------------------------------

tf() { "$TF" -chdir="$INFRA_DIR" "$@"; }

# Deja en VAR_FILES los argumentos -var-file para terraform.
load_var_files() {
  VAR_FILES=("-var-file=$TFVARS_FILE")
}

# Output de Terraform como texto; vacío (sin fallar) si no existe o es null.
tf_out() { { tf output -raw "$1" 2>/dev/null || true; } | tr -d '\r'; }

# Lee un valor simple (string) de demo.tfvars, p. ej.: tfvars_value api_image_tag
tfvars_value() {
  sed -n -E "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/p" "$INFRA_DIR/$TFVARS_FILE" | head -1
}

# --- Variables de las demos (generadas por export-env.sh) -----------------

load_env() {
  local env_file="$DEMOS_DIR/.env"
  [[ -f "$env_file" ]] || die "No existe demos/.env. Ejecuta: scripts/export-env.sh"
  local key value
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    export "$key=${value%$'\r'}"
  done <"$env_file"
}

# --- Llamadas HTTP para las demos -----------------------------------------

# call "<descripción>" <argumentos de curl...>
# Muestra el código de estado (en color) y el body (recortado).
call() {
  local description="$1"; shift
  local output code body color
  printf '\n%s%s%s\n' "$C_BOLD" "$description" "$C_RESET"
  output="$(curl -sS -w $'\n%{http_code}' "$@" || true)"
  code="${output##*$'\n'}"
  body="${output%$'\n'*}"
  case "$code" in
    2*) color="$C_GREEN" ;;
    429|4*|5*) color="$C_RED" ;;
    *) color="$C_YELLOW" ;;
  esac
  printf '  %sHTTP %s%s\n' "$color" "$code" "$C_RESET"
  if [[ -n "$body" ]]; then
    printf '  %s\n' "${body:0:600}"
  fi
  LAST_STATUS="$code"
}

# Pausa entre pasos en vivo. Desactívala con NO_PAUSE=1 (ensayos, plan B).
pause() {
  if [[ -t 0 && "${NO_PAUSE:-0}" != "1" ]]; then
    read -r -p "  [Enter para continuar] " _ || true
  fi
}

# Solo los headers de respuesta (para comparar backend directo vs APIM).
headers() {
  local description="$1"; shift
  printf '\n%s%s%s\n' "$C_BOLD" "$description" "$C_RESET"
  curl -sS -D - -o /dev/null "$@" | tr -d '\r' | sed 's/^/  /'
}
