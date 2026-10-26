# Plan-only tests with mocked providers: no Azure credentials required.

mock_provider "azurerm" {}

mock_provider "azurerm" {
  alias = "hub"
}

variables {
  hub = {
    virtual_network_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-prd-weu/providers/Microsoft.Network/virtualNetworks/vnet-hub-prd-weu"
    firewall_private_ip = "10.100.0.4"
  }

  request = {
    name            = "payments"
    environment     = "prd"
    location        = "westeurope"
    subscription_id = "11111111-1111-1111-1111-111111111111"
    owner           = "team-payments@contoso.com"
    cost_center     = "cc-4100"
    resource_groups = ["app", "data"]
    network = {
      address_space = ["10.110.0.0/22"]
      subnets = {
        app = { address_prefixes = ["10.110.0.0/24"] }
      }
    }
    role_assignments = [{
      principal_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
      role         = "Contributor"
      scope        = "rg:app"
    }]
    budget = {
      amount         = 3500
      start_date     = "2026-11-01T00:00:00Z"
      contact_emails = ["team-payments@contoso.com"]
    }
  }
}

run "builds_the_standard_layout" {
  command = plan

  assert {
    condition     = output.name_token == "payments-prd-weu"
    error_message = "Name token must follow <workload>-<environment>-<region>."
  }

  assert {
    condition     = toset(keys(azurerm_resource_group.this)) == toset(["app", "data", "network"])
    error_message = "Requested resource groups plus a network resource group are expected."
  }

  assert {
    condition     = azurerm_resource_group.this["app"].name == "rg-payments-prd-weu-app"
    error_message = "Resource group names must follow the naming convention."
  }

  assert {
    condition     = length(module.spoke) == 1 && length(azurerm_consumption_budget_subscription.this) == 1
    error_message = "A spoke and a budget are expected for this request."
  }
}

run "mandatory_tags_cannot_be_overridden" {
  command = plan

  variables {
    request = merge(var.request, { tags = { owner = "someone-else@contoso.com", service-tier = "tier-1" } })
  }

  assert {
    condition     = output.tags["owner"] == "team-payments@contoso.com" && output.tags["service-tier"] == "tier-1"
    error_message = "Free-form tags are kept but mandatory tags come from the request fields."
  }
}

run "request_without_network_creates_no_spoke" {
  command = plan

  variables {
    request = merge(var.request, { network = null })
  }

  assert {
    condition     = length(module.spoke) == 0 && !contains(keys(azurerm_resource_group.this), "network")
    error_message = "No spoke and no network resource group are expected without a network block."
  }
}

run "privileged_roles_are_rejected" {
  command = plan

  variables {
    request = merge(var.request, {
      role_assignments = [{
        principal_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        role         = "Owner"
        scope        = "subscription"
      }]
    })
  }

  expect_failures = [var.request]
}

run "unknown_role_scope_is_rejected" {
  command = plan

  variables {
    request = merge(var.request, {
      role_assignments = [{
        principal_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        role         = "Reader"
        scope        = "rg:does-not-exist"
      }]
    })
  }

  expect_failures = [var.request]
}
