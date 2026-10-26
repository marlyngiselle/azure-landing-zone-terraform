locals {
  tags = merge({ managed-by = "terraform" }, var.tags)

  hub_id_parts  = split("/", var.hub.virtual_network_id)
  hub_rg_name   = local.hub_id_parts[4]
  hub_vnet_name = local.hub_id_parts[8]

  firewall_enabled = var.hub.firewall_private_ip != null
  dns_servers      = var.dns_servers != null ? var.dns_servers : (local.firewall_enabled ? [var.hub.firewall_private_ip] : [])

  routed_subnets = { for k, s in var.subnets : k => s if s.route_to_firewall && local.firewall_enabled }

  nsg_rules = merge([
    for subnet_key, s in var.subnets : {
      for r in s.security_rules : "${subnet_key}.${r.name}" => merge(r, { subnet_key = subnet_key })
    }
  ]...)
}

resource "azurerm_virtual_network" "this" {
  # checkov:skip=CKV_AZURE_183:DNS defaults to the hub firewall DNS proxy (a private address) whenever a firewall exists.
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  dns_servers         = local.dns_servers
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints

  default_outbound_access_enabled   = false
  private_endpoint_network_policies = each.value.private_endpoints ? "Enabled" : "Disabled"

  dynamic "delegation" {
    for_each = each.value.delegation_service == null ? [] : [each.value.delegation_service]

    content {
      name = "delegation"

      service_delegation {
        name    = delegation.value
        actions = each.value.delegation_actions
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Network security groups: one per subnet, rules as data
# ---------------------------------------------------------------------------

resource "azurerm_network_security_group" "this" {
  for_each = var.subnets

  name                = "nsg-${var.name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "this" {
  for_each = local.nsg_rules

  name                        = each.value.name
  description                 = each.value.description
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_ranges          = each.value.source_port_ranges
  destination_port_ranges     = each.value.destination_port_ranges
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.value.subnet_key].name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# ---------------------------------------------------------------------------
# Forced egress through the hub firewall
# ---------------------------------------------------------------------------

resource "azurerm_route_table" "this" {
  count = local.firewall_enabled ? 1 : 0

  name                = "rt-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Routes learned from gateways must not bypass the firewall.
  bgp_route_propagation_enabled = false

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.hub.firewall_private_ip
  }

  tags = local.tags
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = local.routed_subnets

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this[0].id
}

# ---------------------------------------------------------------------------
# Hub and spoke peering (both directions)
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${azurerm_virtual_network.this.name}-to-${local.hub_vnet_name}"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.this.name
  remote_virtual_network_id = var.hub.virtual_network_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.hub.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider = azurerm.hub

  name                      = "peer-${local.hub_vnet_name}-to-${azurerm_virtual_network.this.name}"
  resource_group_name       = local.hub_rg_name
  virtual_network_name      = local.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.this.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.hub.use_remote_gateways
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------

module "diagnostics" {
  source = "../management/modules/diagnostic-settings"
  count  = var.log_analytics_workspace_id == null ? 0 : 1

  log_analytics_workspace_id = var.log_analytics_workspace_id
  targets = merge(
    { vnet = { resource_id = azurerm_virtual_network.this.id } },
    { for k, nsg in azurerm_network_security_group.this : "nsg-${k}" => { resource_id = nsg.id, metric_categories = [] } },
  )
}
