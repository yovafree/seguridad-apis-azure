# Versiones fijadas para que la demo sea reproducible.
# Terraform >= 1.11 es necesario por los atributos write-only (value_wo en Key Vault).
terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.8.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.10.0"
    }
    # Solo para lo que azurerm aún no soporta: Easy Auth de Container Apps.
    azapi = {
      source  = "Azure/azapi"
      version = "= 2.13.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.14.2"
    }
  }
}
