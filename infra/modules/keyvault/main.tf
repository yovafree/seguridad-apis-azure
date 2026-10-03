# Key Vault con RBAC para los client secrets de los clientes de la Demo 3.
# Los secrets se escriben con value_wo (atributo write-only, Terraform >= 1.11): el valor
# NO queda guardado en el estado para este recurso. scripts/get-token.sh los lee desde aquí.

variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tenant_id" { type = string }
variable "admin_object_id" {
  description = "Identidad que ejecuta Terraform: recibe permisos para escribir/leer secrets."
  type        = string
}
variable "secret_names" {
  description = "Nombres lógicos de los clientes (full, reader). No sensibles: se usan en for_each."
  type        = list(string)
}
variable "secret_values" {
  type      = map(string)
  sensitive = true
}
variable "secrets_version" { type = number }
variable "tags" { type = map(string) }

resource "azurerm_key_vault" "this" {
  name                       = var.name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false # demo: permite destruir y recrear sin esperar 7+ días
  soft_delete_retention_days = 7
  tags                       = var.tags
}

resource "azurerm_role_assignment" "admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.admin_object_id
}

# Las asignaciones RBAC tardan en propagarse; sin esta espera el primer apply suele fallar con 403.
resource "time_sleep" "rbac" {
  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.admin]
}

resource "azurerm_key_vault_secret" "client" {
  for_each = toset(var.secret_names)

  name             = "client-${each.key}-secret"
  key_vault_id     = azurerm_key_vault.this.id
  value_wo         = var.secret_values[each.key]
  value_wo_version = var.secrets_version
  content_type     = "client-secret"

  depends_on = [time_sleep.rbac]
}

output "name" {
  value = azurerm_key_vault.this.name
}

output "id" {
  value = azurerm_key_vault.this.id
}
