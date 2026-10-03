# Alternativa: backend en Azure App Service

El repo usa **Azure Container Apps**. Si prefieres **App Service (Linux, contenedor)**, todas las demos funcionan igual: el equivalente de cada pieza está abajo. Reemplaza el módulo `infra/modules/container-app` por uno así: una Web App abierta (demos 1-4) y otra cerrada (Demo 5) con el bloque siguiente (no incluido como código ejecutable para no duplicar la infraestructura).

| Container Apps (repo) | App Service (alternativa) |
|---|---|
| `azurerm_container_app_environment` | `azurerm_service_plan` (`os_type = "Linux"`, `sku_name = "B1"` o superior) |
| `azurerm_container_app` + `registry { identity }` | `azurerm_linux_web_app` con `site_config.application_stack.docker_image_name` y `container_registry_use_managed_identity = true` |
| `ingress.ip_security_restriction` | `site_config.ip_restriction` (más `ip_restriction_default_action = "Deny"`) |
| Easy Auth (`authConfigs` vía azapi) | `auth_settings_v2` **nativo de azurerm** (no requiere azapi) |
| `min_replicas = 1` | `site_config.always_on = true` |

```hcl
resource "azurerm_service_plan" "this" {
  name                = "${var.prefix}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "this" {
  name                = "${var.prefix}-orders-api-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.pull.id] # con rol AcrPull sobre el ACR
  }

  app_settings = {
    WEBSITES_PORT = "8080"
  }

  site_config {
    always_on                                     = true
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.pull.client_id
    health_check_path                             = "/health"
    health_check_eviction_time_in_min             = 5

    application_stack {
      docker_registry_url = "https://${var.acr_login_server}"
      docker_image_name   = "orders-api:${var.api_image_tag}"
    }

    # Demo 5, capa de red (solo en el backend cerrado)
    ip_restriction_default_action = "Deny"
    dynamic "ip_restriction" {
      for_each = var.apim_public_ips
      content {
        name       = "apim"
        action     = "Allow"
        ip_address = "${ip_restriction.value}/32"
        priority   = 100
      }
    }
  }

  # Demo 5, capa de identidad (solo en el backend cerrado)
  auth_settings_v2 {
    auth_enabled           = true
    require_authentication = true
    unauthenticated_action = "Return401"
    excluded_paths         = ["/health"]

    active_directory_v2 {
      client_id                  = var.api_client_id
      tenant_auth_endpoint       = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
      allowed_audiences          = [var.api_client_id, var.api_app_id_uri]
      allowed_applications       = [var.apim_identity_client_id]
    }

    login {}
  }
}
```

Diferencias a tener en cuenta:

- App Service agrega sus propios headers (p. ej. `X-Powered-By: ASP.NET` en algunos stacks), lo que sirve igual para la Demo 4.
- Para aislamiento por red en producción, la opción equivalente a "ingress interno" es un **Private Endpoint** en la Web App, con APIM Standard v2 (integración VNet) o Premium.
