terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.40.0, < 5.0.0"
      # Default provider: the landing zone subscription being vended.
      # azurerm.hub: the connectivity subscription that owns the hub VNet.
      configuration_aliases = [azurerm.hub]
    }
  }
}
