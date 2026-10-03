variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "sku_name" { type = string }
variable "publisher_name" { type = string }
variable "publisher_email" { type = string }
variable "tags" { type = map(string) }

variable "backend_urls" {
  description = "URLs de los backends: open (demos 1-4) y locked (Demo 5)."
  type        = object({ open = string, locked = string })
}

variable "openapi_spec_path" {
  description = "Ruta al documento OpenAPI generado por la API (.NET)."
  type        = string
}

variable "policies_path" {
  description = "Carpeta con los .xml de políticas."
  type        = string
}

variable "app_insights_id" { type = string }
variable "app_insights_cs" {
  type      = string
  sensitive = true
}
variable "log_analytics_id" { type = string }

variable "tenant_id" { type = string }
variable "api_client_id" { type = string }
variable "api_app_id_uri" { type = string }
variable "backend_audience" {
  description = "Recurso (audiencia) para el token de Managed Identity hacia el backend cerrado."
  type        = string
}

variable "rate_limit_calls" { type = number }
variable "rate_limit_period" { type = number }
variable "quota_calls" { type = number }
variable "quota_period" { type = number }
variable "max_payload_bytes" { type = number }
