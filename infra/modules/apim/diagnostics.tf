# Observabilidad de APIM:
#  - Application Insights: telemetría por request (logger + diagnostic global).
#  - Log Analytics: GatewayLogs en la tabla ApiManagementGatewayLogs (consultas KQL de la Demo 2).

resource "azurerm_api_management_logger" "appinsights" {
  name                = "appinsights"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  resource_id         = var.app_insights_id

  application_insights {
    connection_string = var.app_insights_cs
  }
}

resource "azurerm_api_management_diagnostic" "appinsights" {
  identifier               = "applicationinsights"
  resource_group_name      = var.resource_group_name
  api_management_name      = azurerm_api_management.this.name
  api_management_logger_id = azurerm_api_management_logger.appinsights.id

  sampling_percentage       = 100 # demo: registrar todo
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"

  # Body en 0 bytes a nivel global: no se guardan datos personales en la telemetría.
  frontend_request {
    body_bytes = 0
  }

  frontend_response {
    body_bytes     = 0
    headers_to_log = ["Retry-After", "X-RateLimit-Remaining"]
  }

  backend_request {
    body_bytes = 0
  }

  backend_response {
    body_bytes = 0
  }
}

resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                           = "to-log-analytics"
  target_resource_id             = azurerm_api_management.this.id
  log_analytics_workspace_id     = var.log_analytics_id
  log_analytics_destination_type = "Dedicated" # tablas por recurso: ApiManagementGatewayLogs

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
