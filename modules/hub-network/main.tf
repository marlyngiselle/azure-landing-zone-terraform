locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name
  tags                = merge({ managed-by = "terraform" }, var.tags)

  deploy_firewall = var.firewall.enabled && var.subnets.firewall != null
  deploy_bastion  = var.bastion.enabled && var.subnets.bastion != null

  # Azure requires these exact subnet names.
  platform_subnets = { for k, v in {
    AzureFirewallSubnet = var.subnets.firewall
    AzureBastionSubnet  = var.subnets.bastion
    GatewaySubnet       = var.subnets.gateway
    "snet-shared"       = var.subnets.shared
  } : k => v if v != null }

  diagnostic_targets = merge(
    local.deploy_firewall ? { firewall = azurerm_firewall.this[0].id } : {},
    local.deploy_bastion ? { bastion = azurerm_bastion_host.this[0].id } : {},
  )
}

resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  address_space       = var.address_space
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  # checkov:skip=CKV2_AZURE_31:AzureFirewallSubnet and GatewaySubnet do not support NSGs; snet-shared gets one below.
  for_each = local.platform_subnets

  name                 = each.key
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]

  # Explicit egress only: workloads leave through the firewall, never through implicit SNAT.
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "shared" {
  count = var.subnets.shared == null ? 0 : 1

  name                = "nsg-${var.name}-shared"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "shared" {
  count = var.subnets.shared == null ? 0 : 1

  subnet_id                 = azurerm_subnet.this["snet-shared"].id
  network_security_group_id = azurerm_network_security_group.shared[0].id
}

# ---------------------------------------------------------------------------
# Azure Firewall
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "firewall" {
  count = local.deploy_firewall ? 1 : 0

  name                = "pip-afw-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.firewall.zones
  tags                = local.tags
}

resource "azurerm_firewall_policy" "this" {
  count = local.deploy_firewall ? 1 : 0

  name                     = "afwp-${var.name}"
  location                 = var.location
  resource_group_name      = local.resource_group_name
  sku                      = var.firewall.sku_tier
  threat_intelligence_mode = var.firewall.threat_intelligence_mode

  dns {
    proxy_enabled = var.firewall.dns_proxy_enabled
    servers       = var.firewall.dns_servers
  }

  dynamic "intrusion_detection" {
    for_each = var.firewall.sku_tier == "Premium" ? [1] : []

    content {
      mode = "Deny"
    }
  }

  tags = local.tags
}

resource "azurerm_firewall" "this" {
  # checkov:skip=CKV_AZURE_216:Threat intelligence is enforced on the attached firewall policy (threat_intelligence_mode defaults to Deny).
  count = local.deploy_firewall ? 1 : 0

  name                = "afw-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall.sku_tier
  firewall_policy_id  = azurerm_firewall_policy.this[0].id
  zones               = var.firewall.zones

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.this["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Azure Bastion
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "bastion" {
  count = local.deploy_bastion ? 1 : 0

  name                = "pip-bas-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.bastion.zones
  tags                = local.tags
}

resource "azurerm_bastion_host" "this" {
  count = local.deploy_bastion ? 1 : 0

  name                = "bas-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  sku                 = var.bastion.sku
  zones               = var.bastion.zones
  copy_paste_enabled  = var.bastion.copy_paste_enabled
  tunneling_enabled   = var.bastion.sku == "Basic" ? false : var.bastion.tunneling_enabled

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.this["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Private DNS for PaaS private endpoints
# ---------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "this" {
  for_each = var.private_dns_zones

  name                = each.value
  resource_group_name = local.resource_group_name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = var.private_dns_zones

  name                  = "link-${azurerm_virtual_network.this.name}"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value].name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = local.tags
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------

module "diagnostics" {
  source = "../management/modules/diagnostic-settings"
  count  = var.log_analytics_workspace_id == null ? 0 : 1

  log_analytics_workspace_id = var.log_analytics_workspace_id
  targets = {
    for k, id in merge(
      { vnet = azurerm_virtual_network.this.id },
      local.diagnostic_targets,
    ) : k => { resource_id = id, destination_dedicated = k == "firewall" }
  }
}
