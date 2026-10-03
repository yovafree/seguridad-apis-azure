# Backends: Azure Container Apps con la imagen orders-api desde ACR.
#
# Se crean DOS apps con la misma imagen, en el mismo entorno:
#   - open   -> demos 1-4: cualquiera puede llamarla directamente (el "problema" que resuelve APIM).
#   - locked -> Demo 5: solo acepta tráfico de APIM, con dos capas independientes:
#       * Red: ip_security_restriction en el ingress -> solo la IP de APIM (Developer tiene IP estática).
#       * Identidad: Easy Auth (authConfigs, vía azapi porque azurerm no lo soporta) exige un token
#         de Entra ID con la audiencia de la API y emitido para la Managed Identity de APIM.
#
# Alternativa para producción (documentada en demos/demo5/README.md): APIM Standard v2 con
# integración VNet + entorno de Container Apps interno.

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
    azapi   = { source = "Azure/azapi" }
    time    = { source = "hashicorp/time" }
  }
}

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment_name" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "acr_id" { type = string }
variable "acr_login_server" { type = string }
variable "image" { type = string }
variable "tags" { type = map(string) }

variable "apps" {
  description = "Apps a crear. allowed_ips vacía = abierta a Internet; enable_auth = Easy Auth."
  type = map(object({
    name        = string
    allowed_ips = list(string)
    enable_auth = bool
  }))
}

variable "auth_tenant_id" { type = string }
variable "auth_client_id" { type = string }
variable "auth_allowed_audiences" { type = list(string) }
variable "auth_allowed_client_apps" { type = list(string) }

resource "azurerm_container_app_environment" "this" {
  name                       = var.environment_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = var.log_analytics_workspace_id
  tags                       = var.tags
}

# Identidad para descargar la imagen de ACR sin credenciales (compartida por las dos apps).
resource "azurerm_user_assigned_identity" "pull" {
  name                = "${var.environment_name}-acr-pull"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.pull.principal_id
}

resource "time_sleep" "acr_pull_propagation" {
  create_duration = "45s"
  depends_on      = [azurerm_role_assignment.acr_pull]
}

resource "azurerm_container_app" "this" {
  for_each = var.apps

  name                         = each.value.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.pull.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.pull.id
  }

  ingress {
    external_enabled           = true
    target_port                = 8080
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }

    dynamic "ip_security_restriction" {
      for_each = each.value.allowed_ips
      content {
        name             = "allow-${replace(replace(ip_security_restriction.value, ".", "-"), "/", "_")}"
        description      = "Permitido (Demo 5)"
        action           = "Allow"
        ip_address_range = strcontains(ip_security_restriction.value, "/") ? ip_security_restriction.value : "${ip_security_restriction.value}/32"
      }
    }
  }

  template {
    # Una sola réplica siempre encendida: sin cold start en vivo y datos en memoria consistentes.
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "orders-api"
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"

      liveness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/health"
      }
    }
  }

  depends_on = [time_sleep.acr_pull_propagation]
}

# Easy Auth solo en las apps con enable_auth (el backend cerrado de la Demo 5).
resource "azapi_resource" "auth" {
  for_each = { for key, app in var.apps : key => app if app.enable_auth }

  type      = "Microsoft.App/containerApps/authConfigs@2024-03-01"
  name      = "current"
  parent_id = azurerm_container_app.this[each.key].id

  body = {
    properties = {
      platform = {
        enabled = true
      }
      globalValidation = {
        unauthenticatedClientAction = "Return401"
        excludedPaths               = ["/health"]
      }
      identityProviders = {
        azureActiveDirectory = {
          enabled = true
          registration = {
            clientId     = var.auth_client_id
            openIdIssuer = "https://login.microsoftonline.com/${var.auth_tenant_id}/v2.0"
          }
          validation = {
            allowedAudiences = var.auth_allowed_audiences
            # Solo la Managed Identity de APIM: un token válido de otro cliente recibe 403.
            defaultAuthorizationPolicy = {
              allowedApplications = var.auth_allowed_client_apps
            }
          }
        }
      }
    }
  }
}

output "names" {
  value = { for key, app in azurerm_container_app.this : key => app.name }
}

output "urls" {
  value = { for key, app in azurerm_container_app.this : key => "https://${app.ingress[0].fqdn}" }
}
