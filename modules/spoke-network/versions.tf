terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.40.0, < 5.0.0"
      # The default provider targets the spoke subscription; azurerm.hub targets
      # the connectivity subscription so the hub-side peering can be created.
      configuration_aliases = [azurerm.hub]
    }
  }
}
