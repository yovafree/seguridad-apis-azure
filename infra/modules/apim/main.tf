# Azure API Management: servicio, una API por demo (todas importadas desde el mismo OpenAPI),
# producto "Basic", suscripción de la demo, named values, policy fragments y políticas.
#
# Todo se despliega UNA sola vez: cada demo vive en su propia ruta con sus políticas ya activas,
# así que en la charla solo se cambia la URL (sin terraform apply en vivo).

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

locals {
  # Named values: valores de configuración (no secretos) que las políticas usan como {{nombre}}.
  named_values = {
    "orders-tenant-id"        = var.tenant_id
    "orders-api-audience"     = var.api_client_id
    "orders-api-app-id-uri"   = var.api_app_id_uri
    "orders-backend-audience" = var.backend_audience
  }

  # Un fragment por política/demo (infra/policies/<nombre>.xml). Se ven en el portal (Policy fragments).
  fragments = {
    "common-on-error"     = "Errores en formato ProblemDetails (429, 400/413, 401)"
    "demo2-rate-limit"    = "Demo 2: rate-limit-by-key"
    "demo2-quota"         = "Demo 2: quota-by-key"
    "demo3-jwt"           = "Demo 3: valida el token de Entra ID y el rol requerido por la operación"
    "demo4-validate"      = "Demo 4: validate-parameters + validate-content contra el esquema OpenAPI"
    "demo4-strip-headers" = "Demo 4: elimina headers que revelan la plataforma del backend"
    "demo5-backend-mi"    = "Demo 5: token de Managed Identity hacia el backend cerrado"
  }

  fragment_vars = {
    rate_limit_calls  = var.rate_limit_calls
    rate_limit_period = var.rate_limit_period
    quota_calls       = var.quota_calls
    quota_period      = var.quota_period
    max_payload_bytes = var.max_payload_bytes
  }

  # Una API por demo: https://<apim>.azure-api.net/<demo>/orders
  #   backend  -> "open" (Container App abierta) o "locked" (solo acepta a APIM)
  #   inbound / outbound -> fragments que incluye la política de la API
  demos = {
    demo1 = { title = "Demo 1 - Suscripción", backend = "open", inbound = [], outbound = [] }
    demo2 = { title = "Demo 2 - Rate limit y cuota", backend = "open", inbound = ["demo2-rate-limit", "demo2-quota"], outbound = [] }
    demo3 = { title = "Demo 3 - JWT con Entra ID", backend = "open", inbound = ["demo3-jwt"], outbound = [] }
    demo4 = { title = "Demo 4 - Validación", backend = "open", inbound = ["demo4-validate"], outbound = ["demo4-strip-headers"] }
    demo5 = { title = "Demo 5 - Backend cerrado", backend = "locked", inbound = ["demo5-backend-mi"], outbound = [] }
  }

  # Rol requerido por operación (solo Demo 3). Los ids salen de los operationId del OpenAPI.
  operation_roles = {
    "list-orders"  = "Orders.Read"
    "get-order"    = "Orders.Read"
    "create-order" = "Orders.Write"
    "delete-order" = "Orders.Write"
  }
}

resource "azurerm_api_management" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name
  tags                = var.tags

  # Identidad usada por authentication-managed-identity (Demo 5).
  identity {
    type = "SystemAssigned"
  }

  # El tier Developer puede tardar 30-60 minutos en aprovisionarse.
  timeouts {
    create = "3h"
    update = "3h"
    delete = "3h"
  }
}

resource "azurerm_api_management_named_value" "this" {
  for_each = local.named_values

  name                = each.key
  display_name        = each.key
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  value               = each.value
}

resource "azurerm_api_management_policy_fragment" "this" {
  for_each = local.fragments

  api_management_id = azurerm_api_management.this.id
  name              = each.key
  description       = each.value
  format            = "rawxml"
  value             = templatefile("${var.policies_path}/${each.key}.xml", local.fragment_vars)

  depends_on = [azurerm_api_management_named_value.this]
}

# ---------------------------------------------------------------------------
# Una API por demo, importada desde la especificación OpenAPI de la API .NET.
# ---------------------------------------------------------------------------

resource "azurerm_api_management_api" "orders" {
  for_each = local.demos

  name                  = "orders-${each.key}"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.this.name
  revision              = "1"
  display_name          = each.value.title
  path                  = each.key
  protocols             = ["https"]
  service_url           = var.backend_urls[each.value.backend]
  subscription_required = true

  subscription_key_parameter_names {
    header = "Ocp-Apim-Subscription-Key"
    query  = "subscription-key"
  }

  import {
    content_format = "openapi+json"
    content_value  = file(var.openapi_spec_path)
  }
}

resource "azurerm_api_management_product" "basic" {
  product_id            = "basic"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.this.name
  display_name          = "Basic"
  description           = "Producto de la demo: requiere suscripción."
  subscription_required = true
  approval_required     = false
  published             = true
}

resource "azurerm_api_management_product_api" "orders" {
  for_each = azurerm_api_management_api.orders

  product_id          = azurerm_api_management_product.basic.product_id
  api_name            = each.value.name
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
}

# Una sola suscripción (una sola key) para todas las demos.
resource "azurerm_api_management_subscription" "demo" {
  display_name        = "Demo - charla"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  product_id          = azurerm_api_management_product.basic.id
  state               = "active"
  allow_tracing       = false
}

# ---------------------------------------------------------------------------
# Políticas
# ---------------------------------------------------------------------------

resource "azurerm_api_management_api_policy" "orders" {
  for_each = local.demos

  api_name            = azurerm_api_management_api.orders[each.key].name
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  xml_content = templatefile("${var.policies_path}/api-policy.xml.tftpl", {
    demo     = each.value.title
    inbound  = each.value.inbound
    outbound = each.value.outbound
  })

  depends_on = [azurerm_api_management_policy_fragment.this]
}

# Demo 3: cada operación declara el rol que exige; demo3-jwt lo verifica.
resource "azurerm_api_management_api_operation_policy" "role" {
  for_each = local.operation_roles

  api_name            = azurerm_api_management_api.orders["demo3"].name
  operation_id        = each.key
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  xml_content         = templatefile("${var.policies_path}/operation-policy.xml.tftpl", { required_role = each.value })
}
