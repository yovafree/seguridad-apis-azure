# ---------------------------------------------------------------------------
# Configuración general
# ---------------------------------------------------------------------------

variable "prefix" {
  description = "Prefijo para el nombre de todos los recursos (3-10 caracteres, minúsculas y números)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.prefix))
    error_message = "El prefijo debe tener 3-10 caracteres: minúsculas y números, empezando por letra."
  }
}

variable "location" {
  description = "Región de Azure."
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Tags comunes para todos los recursos."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# API Management
# ---------------------------------------------------------------------------

variable "apim_sku" {
  description = <<-EOT
    SKU de APIM. Recomendado: Developer_1 (IP estática para cerrar el backend de la Demo 5 y
    todas las políticas; tarda 30-60 min en crearse). BasicV2_1 se crea en minutos, pero no tiene IP
    de salida determinista: la restricción por IP de la Demo 5 no sirve con ese tier.
  EOT
  type        = string
  default     = "Developer_1"
}

variable "apim_publisher_name" {
  description = "Nombre del publicador que muestra APIM."
  type        = string
  default     = "Demo Seguridad APIs"
}

variable "apim_publisher_email" {
  description = "Email del publicador de APIM (recibe notificaciones del servicio)."
  type        = string
}

# ---------------------------------------------------------------------------
# Backend
# ---------------------------------------------------------------------------

variable "api_image_tag" {
  description = "Tag de la imagen orders-api en ACR."
  type        = string
  default     = "1.0.0"
}

# ---------------------------------------------------------------------------
# Parámetros de las políticas
# ---------------------------------------------------------------------------

variable "rate_limit_calls" {
  description = "Llamadas permitidas por ventana (Demo 2)."
  type        = number
  default     = 10
}

variable "rate_limit_period" {
  description = "Ventana del rate limit en segundos (máximo 300)."
  type        = number
  default     = 60
}

variable "quota_calls" {
  description = "Cuota de llamadas por período (Demo 2)."
  type        = number
  default     = 1000
}

variable "quota_period" {
  description = "Período de la cuota en segundos (mínimo 300). 86400 = un día."
  type        = number
  default     = 86400
}

variable "max_payload_bytes" {
  description = "Tamaño máximo del body aceptado por validate-content (Demo 4)."
  type        = number
  default     = 2048
}

variable "lockdown_extra_allowed_ips" {
  description = "IPs/CIDR adicionales permitidas en el backend cerrado de la Demo 5 (p. ej. tu IP para depurar)."
  type        = list(string)
  default     = []
}

variable "client_secret_rotation_days" {
  description = "Cada cuántos días Terraform rota los client secrets de Entra ID."
  type        = number
  default     = 30
}
