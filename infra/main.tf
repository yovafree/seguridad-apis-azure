data "azurerm_client_config" "current" {}

# Sufijo aleatorio para los nombres que deben ser únicos a nivel global (APIM, ACR, Key Vault).
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  suffix = random_string.suffix.result
  tags   = merge({ proyecto = "seguridad-apis-azure", prefijo = var.prefix }, var.tags)

  names = {
    resource_group = "${var.prefix}-rg"
    acr            = "${var.prefix}acr${local.suffix}"
    key_vault      = "${var.prefix}-kv-${local.suffix}"
    apim           = "${var.prefix}-apim-${local.suffix}"
    log_analytics  = "${var.prefix}-log"
    app_insights   = "${var.prefix}-appi"
    cae            = "${var.prefix}-cae"
    app_open       = "${var.prefix}-orders-open"
    app_locked     = "${var.prefix}-orders-locked"
  }

  openapi_spec_path = "${path.root}/../src/Orders.Api/openapi/orders.json"
}

resource "azurerm_resource_group" "this" {
  name     = local.names.resource_group
  location = var.location
  tags     = local.tags
}

# El registro se crea primero (deploy.sh hace un apply con -target) para poder publicar
# la imagen antes de crear la Container App.
resource "azurerm_container_registry" "this" {
  name                = local.names.acr
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = false # la Container App descarga la imagen con Managed Identity
  tags                = local.tags
}

module "observability" {
  source = "./modules/observability"

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  log_analytics_name  = local.names.log_analytics
  app_insights_name   = local.names.app_insights
  tags                = local.tags
}

module "identity" {
  source = "./modules/identity"

  prefix                      = var.prefix
  client_secret_rotation_days = var.client_secret_rotation_days
}

module "keyvault" {
  source = "./modules/keyvault"

  name                = local.names.key_vault
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  admin_object_id     = data.azurerm_client_config.current.object_id
  secret_names        = keys(module.identity.client_ids)
  secret_values       = module.identity.client_secrets
  secrets_version     = module.identity.secrets_version
  tags                = local.tags
}

module "apim" {
  source = "./modules/apim"

  name                = local.names.apim
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku_name            = var.apim_sku
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  tags                = local.tags
  backend_urls        = { open = module.container_app.urls["open"], locked = module.container_app.urls["locked"] }
  openapi_spec_path   = local.openapi_spec_path
  policies_path       = "${path.root}/policies"
  app_insights_id     = module.observability.app_insights_id
  app_insights_cs     = module.observability.app_insights_connection_string
  log_analytics_id    = module.observability.log_analytics_id
  tenant_id           = module.identity.tenant_id
  api_client_id       = module.identity.api_client_id
  api_app_id_uri      = module.identity.api_app_id_uri
  backend_audience    = module.identity.api_client_id

  rate_limit_calls  = var.rate_limit_calls
  rate_limit_period = var.rate_limit_period
  quota_calls       = var.quota_calls
  quota_period      = var.quota_period
  max_payload_bytes = var.max_payload_bytes
}

# La Managed Identity de APIM vista como service principal: Easy Auth necesita su client id (appid)
# para aceptar únicamente los tokens que emite APIM.
data "azuread_service_principal" "apim" {
  object_id = module.apim.principal_id
}

module "container_app" {
  source = "./modules/container-app"

  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  environment_name           = local.names.cae
  log_analytics_workspace_id = module.observability.log_analytics_id
  acr_id                     = azurerm_container_registry.this.id
  acr_login_server           = azurerm_container_registry.this.login_server
  image                      = "${azurerm_container_registry.this.login_server}/orders-api:${var.api_image_tag}"
  tags                       = local.tags

  apps = {
    # Demos 1-4: backend abierto (se puede llamar sin pasar por APIM).
    open = { name = local.names.app_open, allowed_ips = [], enable_auth = false }

    # Demo 5: backend cerrado. Red: solo la IP pública (estática) de APIM.
    # Identidad: Easy Auth exige un token emitido para la API y solo de la identidad de APIM.
    locked = {
      name        = local.names.app_locked
      allowed_ips = concat(module.apim.public_ip_addresses, var.lockdown_extra_allowed_ips)
      enable_auth = true
    }
  }

  auth_tenant_id           = module.identity.tenant_id
  auth_client_id           = module.identity.api_client_id
  auth_allowed_audiences   = [module.identity.api_client_id, module.identity.api_app_id_uri]
  auth_allowed_client_apps = [data.azuread_service_principal.apim.client_id]
}
