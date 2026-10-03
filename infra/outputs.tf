# Los scripts (scripts/*.sh) leen estos valores con `terraform output -raw <nombre>`.

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "acr_name" {
  value = azurerm_container_registry.this.name
}

output "acr_login_server" {
  value = azurerm_container_registry.this.login_server
}

output "apim_name" {
  value = module.apim.name
}

output "apim_public_ip_addresses" {
  description = "IP(s) públicas de APIM: el origen de las llamadas al backend cerrado (Demo 5)."
  value       = module.apim.public_ip_addresses
}

output "apim_url" {
  description = "URL base de APIM. Cada demo vive en <apim_url>/<demoN>/orders."
  value       = module.apim.gateway_url
}

output "backend_url" {
  description = "URL directa del backend abierto (demos 1-4), sin pasar por APIM."
  value       = module.container_app.urls["open"]
}

output "backend_locked_url" {
  description = "URL directa del backend cerrado (Demo 5): solo acepta tráfico de APIM."
  value       = module.container_app.urls["locked"]
}

output "container_app_name" {
  description = "Nombre de la Container App abierta (para ver sus logs en la Demo 4)."
  value       = module.container_app.names["open"]
}

output "subscription_key" {
  description = "Subscription key del producto Basic."
  value       = module.apim.subscription_key
  sensitive   = true
}

output "tenant_id" {
  value = module.identity.tenant_id
}

output "api_client_id" {
  description = "Client id de la app registration de la API (audiencia de los tokens)."
  value       = module.identity.api_client_id
}

output "api_scope" {
  description = "Scope para client credentials."
  value       = "${module.identity.api_app_id_uri}/.default"
}

output "client_full_id" {
  description = "Cliente con roles Orders.Read y Orders.Write."
  value       = module.identity.client_ids["full"]
}

output "client_reader_id" {
  description = "Cliente solo con Orders.Read."
  value       = module.identity.client_ids["reader"]
}

output "key_vault_name" {
  description = "Key Vault con los client secrets (client-full-secret, client-reader-secret)."
  value       = module.keyvault.name
}

output "log_analytics_workspace_id" {
  description = "Workspace (customer) id para `az monitor log-analytics query`."
  value       = module.observability.log_analytics_workspace_id
}
