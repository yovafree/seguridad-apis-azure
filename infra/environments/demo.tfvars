# Configuración de la charla. Todas las demos se despliegan a la vez (una API de APIM por demo):
# no hay que aplicar cambios durante la presentación.

prefix               = "apisec"
location             = "eastus2"
apim_sku             = "Developer_1"
apim_publisher_name  = "Demo Seguridad APIs"
apim_publisher_email = "me@yovadeleon.dev"
api_image_tag        = "1.0.0"

tags = {
  evento = "charla-seguridad-apis"
}

# --- Parámetros de las políticas ---
rate_limit_calls  = 10
rate_limit_period = 60
quota_calls       = 1000
quota_period      = 86400
max_payload_bytes = 2048
