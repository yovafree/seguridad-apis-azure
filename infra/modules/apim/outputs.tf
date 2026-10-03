output "id" {
  value = azurerm_api_management.this.id
}

output "name" {
  value = azurerm_api_management.this.name
}

output "gateway_url" {
  value = azurerm_api_management.this.gateway_url
}

output "public_ip_addresses" {
  value = azurerm_api_management.this.public_ip_addresses
}

output "principal_id" {
  value = azurerm_api_management.this.identity[0].principal_id
}

output "subscription_key" {
  value     = azurerm_api_management_subscription.demo.primary_key
  sensitive = true
}
