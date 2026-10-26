# Plan-only tests with a mocked provider: no Azure credentials required.

mock_provider "azurerm" {}

variables {
  name                = "hub-prd-weu"
  location            = "westeurope"
  resource_group_name = "rg-hub-prd-weu"
  address_space       = ["10.100.0.0/22"]
  subnets = {
    firewall = "10.100.0.0/26"
    bastion  = "10.100.0.64/26"
    shared   = "10.100.1.0/24"
  }
}

run "firewall_on_bastion_off_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_firewall.this) == 1 && length(azurerm_bastion_host.this) == 0
    error_message = "Defaults must deploy the firewall and skip Bastion."
  }

  assert {
    condition     = azurerm_firewall_policy.this[0].threat_intelligence_mode == "Deny"
    error_message = "Threat intelligence must deny by default."
  }

  assert {
    condition     = contains(keys(azurerm_subnet.this), "AzureFirewallSubnet") && contains(keys(azurerm_subnet.this), "snet-shared")
    error_message = "Platform subnets must use the names Azure requires."
  }
}

run "firewall_can_be_disabled" {
  command = plan

  variables {
    firewall = { enabled = false }
    bastion  = { enabled = true }
  }

  assert {
    condition     = length(azurerm_firewall.this) == 0 && length(azurerm_public_ip.firewall) == 0 && length(azurerm_bastion_host.this) == 1
    error_message = "Disabling the firewall must remove the firewall and its public IP."
  }
}

run "rejects_undersized_firewall_subnet" {
  command = plan

  variables {
    subnets = { firewall = "10.100.0.0/27" }
  }

  expect_failures = [var.subnets]
}
