# La suscripción se toma de ARM_SUBSCRIPTION_ID (scripts/lib.sh la exporta desde `az account show`).
provider "azurerm" {
  # azurerm 5.x ya no registra Resource Providers por defecto: registramos solo los que usamos.
  resource_providers_to_register = [
    "Microsoft.ApiManagement",
    "Microsoft.App",
    "Microsoft.ContainerRegistry",
    "Microsoft.Insights",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.OperationalInsights",
  ]

  features {
    api_management {
      # Un APIM borrado queda en soft-delete; purgarlo permite recrearlo con el mismo nombre.
      purge_soft_delete_on_destroy = true
      recover_soft_deleted         = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Usa la sesión de `az login` (tenant actual).
provider "azuread" {}

provider "azapi" {}
