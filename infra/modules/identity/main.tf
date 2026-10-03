# App registrations de Microsoft Entra ID (provider azuread).
#
# - API "orders-api": expone los app roles Orders.Read y Orders.Write. Con client credentials
#   no existen scopes delegados; los permisos llegan en el claim "roles" del token.
# - Clientes:
#     full   -> Orders.Read + Orders.Write (todo 200)
#     reader -> solo Orders.Read           (POST/DELETE -> 403 en la Demo 3)
#
# Requiere que tu usuario pueda crear app registrations y conceder app roles (admin consent):
# rol "Cloud Application Administrator" o "Application Administrator" en el tenant.

variable "prefix" { type = string }
variable "client_secret_rotation_days" { type = number }

data "azuread_client_config" "current" {}

locals {
  roles = {
    "Orders.Read"  = "Leer pedidos"
    "Orders.Write" = "Crear y eliminar pedidos"
  }

  clients = {
    full   = ["Orders.Read", "Orders.Write"]
    reader = ["Orders.Read"]
  }

  # Pares cliente/rol para las asignaciones (equivalen al admin consent).
  client_roles = merge([
    for client, roles in local.clients : {
      for role in roles : "${client}-${role}" => { client = client, role = role }
    }
  ]...)
}

resource "random_uuid" "role" {
  for_each = local.roles
}

resource "azuread_application" "api" {
  display_name     = "${var.prefix}-orders-api"
  owners           = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"

  api {
    # Tokens v2: audiencia = client id de la API, y el claim "azp" identifica al cliente.
    requested_access_token_version = 2
  }

  dynamic "app_role" {
    for_each = local.roles
    content {
      allowed_member_types = ["Application"]
      description          = app_role.value
      display_name         = app_role.value
      enabled              = true
      id                   = random_uuid.role[app_role.key].result
      value                = app_role.key
    }
  }

  lifecycle {
    # El identifier URI se gestiona con azuread_application_identifier_uri.
    ignore_changes = [identifier_uris]
  }
}

# api://<client-id>: formato aceptado por la política de URIs de cualquier tenant.
resource "azuread_application_identifier_uri" "api" {
  application_id = azuread_application.api.id
  identifier_uri = "api://${azuread_application.api.client_id}"
}

resource "azuread_service_principal" "api" {
  client_id = azuread_application.api.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application" "client" {
  for_each = local.clients

  display_name     = "${var.prefix}-orders-client-${each.key}"
  owners           = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"

  required_resource_access {
    resource_app_id = azuread_application.api.client_id

    dynamic "resource_access" {
      for_each = each.value
      content {
        id   = azuread_application.api.app_role_ids[resource_access.value]
        type = "Role"
      }
    }
  }
}

resource "azuread_service_principal" "client" {
  for_each = local.clients

  client_id = azuread_application.client[each.key].client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_app_role_assignment" "client" {
  for_each = local.client_roles

  app_role_id         = azuread_application.api.app_role_ids[each.value.role]
  principal_object_id = azuread_service_principal.client[each.value.client].object_id
  resource_object_id  = azuread_service_principal.api.object_id
}

# Rotación automática: cuando vence time_rotating, el próximo apply crea un secret nuevo.
resource "time_rotating" "secrets" {
  rotation_days = var.client_secret_rotation_days
}

resource "azuread_application_password" "client" {
  for_each = local.clients

  application_id    = azuread_application.client[each.key].id
  display_name      = "terraform-demo"
  end_date_relative = "${(var.client_secret_rotation_days + 7) * 24}h"

  rotate_when_changed = {
    rotation = time_rotating.secrets.id
  }
}

output "tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

output "api_client_id" {
  value = azuread_application.api.client_id
}

output "api_app_id_uri" {
  value = azuread_application_identifier_uri.api.identifier_uri
}

output "client_ids" {
  value = { for k, app in azuread_application.client : k => app.client_id }
}

output "client_secrets" {
  value     = { for k, pwd in azuread_application_password.client : k => pwd.value }
  sensitive = true
}

# Cambia con cada rotación: obliga a reescribir los secrets (write-only) en Key Vault.
output "secrets_version" {
  value = time_rotating.secrets.unix
}
