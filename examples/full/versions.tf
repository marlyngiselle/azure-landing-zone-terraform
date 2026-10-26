terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40"
    }
  }

  # One state per landing zone: the pipeline passes a backend key derived
  # from the request file name, for example -backend-config="key=lz/payments-prd.tfstate".
  # backend "azurerm" {}
}

# Platform subscription: management and connectivity.
provider "azurerm" {
  features {}
  subscription_id                 = var.platform_subscription_id
  resource_provider_registrations = "core"
  storage_use_azuread             = true
}

# Landing zone subscription, resolved from the request being applied.
provider "azurerm" {
  alias = "landing_zone"
  features {}
  subscription_id                 = local.request.subscription_id
  resource_provider_registrations = "core"
  storage_use_azuread             = true
}
