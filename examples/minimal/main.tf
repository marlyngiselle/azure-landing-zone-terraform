# Minimal landing zone in a single subscription:
# Log Analytics + hub VNet with private DNS + one spoke + the policy baseline in audit mode.
# No firewall and no Bastion, so it costs close to nothing to stand up and tear down.

locals {
  tags = {
    owner               = "platform-team@contoso.com"
    cost-center         = "cc-0000"
    environment         = "dev"
    workload            = "sandbox"
    data-classification = "internal"
  }
}

module "management" {
  source = "../../modules/management"

  name                = "mgmt-dev-weu"
  location            = var.location
  resource_group_name = "rg-mgmt-dev-weu"
  log_analytics       = { retention_in_days = 30 }
  tags                = local.tags
}

module "hub" {
  source = "../../modules/hub-network"

  name                = "hub-dev-weu"
  location            = var.location
  resource_group_name = "rg-hub-dev-weu"
  address_space       = ["10.0.0.0/23"]

  subnets = {
    shared = "10.0.1.0/24"
  }

  firewall          = { enabled = false }
  private_dns_zones = ["privatelink.blob.core.windows.net", "privatelink.vaultcore.azure.net"]

  log_analytics_workspace_id = module.management.log_analytics_workspace_id
  tags                       = local.tags
}

resource "azurerm_resource_group" "spoke" {
  name     = "rg-sandbox-dev-weu-network"
  location = var.location
  tags     = local.tags
}

module "spoke" {
  source = "../../modules/spoke-network"

  # Single subscription: the hub side of the peering uses the same provider.
  providers = {
    azurerm     = azurerm
    azurerm.hub = azurerm
  }

  name                = "sandbox-dev-weu"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = ["10.1.0.0/24"]

  hub = {
    virtual_network_id = module.hub.virtual_network_id
  }

  subnets = {
    app = {
      address_prefixes = ["10.1.0.0/26"]
      security_rules = [{
        name                    = "allow-https-from-vnet"
        priority                = 200
        direction               = "Inbound"
        access                  = "Allow"
        protocol                = "Tcp"
        source_address_prefix   = "VirtualNetwork"
        destination_port_ranges = ["443"]
      }]
    }
    pe = {
      address_prefixes  = ["10.1.0.64/27"]
      private_endpoints = true
    }
  }

  log_analytics_workspace_id = module.management.log_analytics_workspace_id
  tags                       = local.tags
}

module "policy" {
  source = "../../modules/policy-baseline"

  scope = {
    type = "subscription"
    id   = "/subscriptions/${var.subscription_id}"
  }

  allowed_locations = [var.location]

  # Report only: a sandbox should surface drift, not block experiments.
  assignment = { enforce = false }
}
