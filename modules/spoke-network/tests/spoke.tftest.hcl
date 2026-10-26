# Plan-only tests with mocked providers: no Azure credentials required.

mock_provider "azurerm" {}

mock_provider "azurerm" {
  alias = "hub"
}

variables {
  name                = "app-dev-weu"
  location            = "westeurope"
  resource_group_name = "rg-app-dev-weu-network"
  address_space       = ["10.1.0.0/24"]

  hub = {
    virtual_network_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dev-weu/providers/Microsoft.Network/virtualNetworks/vnet-hub-dev-weu"
    firewall_private_ip = "10.0.0.4"
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
      route_to_firewall = false
    }
  }
}

run "egress_is_forced_through_the_firewall" {
  command = plan

  assert {
    condition     = length(azurerm_route_table.this) == 1 && azurerm_route_table.this[0].bgp_route_propagation_enabled == false
    error_message = "A route table with BGP propagation disabled is expected when the hub has a firewall."
  }

  assert {
    condition     = keys(azurerm_subnet_route_table_association.this) == ["app"]
    error_message = "Only subnets with route_to_firewall = true should be associated with the route table."
  }

  assert {
    condition     = azurerm_virtual_network.this.dns_servers == tolist(["10.0.0.4"])
    error_message = "The spoke should resolve DNS through the firewall DNS proxy."
  }
}

run "every_subnet_gets_an_nsg" {
  command = plan

  assert {
    condition     = length(azurerm_subnet_network_security_group_association.this) == length(var.subnets)
    error_message = "Every subnet must be associated with an NSG."
  }

  assert {
    condition     = alltrue([for s in azurerm_subnet.this : s.default_outbound_access_enabled == false])
    error_message = "Default outbound access must be disabled on every subnet."
  }
}

run "peering_is_created_on_both_sides" {
  command = plan

  assert {
    condition     = azurerm_virtual_network_peering.hub_to_spoke.virtual_network_name == "vnet-hub-dev-weu" && azurerm_virtual_network_peering.hub_to_spoke.resource_group_name == "rg-hub-dev-weu"
    error_message = "The hub-side peering must target the hub VNet parsed from its resource ID."
  }
}

run "hub_without_firewall_has_no_route_table" {
  command = plan

  variables {
    hub = {
      virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dev-weu/providers/Microsoft.Network/virtualNetworks/vnet-hub-dev-weu"
    }
  }

  assert {
    condition     = length(azurerm_route_table.this) == 0 && length(azurerm_subnet_route_table_association.this) == 0
    error_message = "No route table is expected without a firewall."
  }
}

run "rejects_invalid_nsg_priority" {
  command = plan

  variables {
    subnets = {
      app = {
        address_prefixes = ["10.1.0.0/26"]
        security_rules = [{
          name                    = "too-low"
          priority                = 50
          direction               = "Inbound"
          access                  = "Allow"
          protocol                = "Tcp"
          source_address_prefix   = "VirtualNetwork"
          destination_port_ranges = ["443"]
        }]
      }
    }
  }

  expect_failures = [var.subnets]
}
