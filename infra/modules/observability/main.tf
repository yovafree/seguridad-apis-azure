# Log Analytics + Application Insights (basado en workspace).
# APIM envía: telemetría de requests a Application Insights (logger + diagnostic, ver módulo apim)
# y GatewayLogs a Log Analytics (diagnostic setting), que es donde se consultan los 429 con KQL.

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "log_analytics_name" { type = string }
variable "app_insights_name" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = var.app_insights_name
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = var.tags
}

output "log_analytics_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.workspace_id
}

output "app_insights_id" {
  value = azurerm_application_insights.this.id
}

output "app_insights_connection_string" {
  value     = azurerm_application_insights.this.connection_string
  sensitive = true
}
