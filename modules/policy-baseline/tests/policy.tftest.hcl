# Plan-only tests with a mocked provider: no Azure credentials required.

mock_provider "azurerm" {}

variables {
  allowed_locations = ["westeurope", "northeurope"]
  scope = {
    type = "management_group"
    id   = "/providers/Microsoft.Management/managementGroups/contoso-landingzones"
  }
}

run "management_group_scope" {
  command = plan

  assert {
    condition     = length(azurerm_management_group_policy_set_definition.this) == 1 && length(azurerm_policy_set_definition.this) == 0
    error_message = "A management group scope must use the management group initiative resource."
  }

  assert {
    condition     = length(azurerm_management_group_policy_assignment.this) == 1 && length(azurerm_subscription_policy_assignment.this) == 0
    error_message = "A management group scope must produce a management group assignment."
  }

  assert {
    condition     = toset(keys(azurerm_policy_definition.this)) == toset(["allowed-locations", "deny-public-ip-on-nic", "require-diagnostic-settings", "require-tag"])
    error_message = "All four custom definitions are expected."
  }

  assert {
    condition     = length(azurerm_management_group_policy_set_definition.this[0].policy_definition_reference) == 3 + length(var.required_tags)
    error_message = "One reference per control plus one per required tag is expected."
  }
}

run "subscription_scope" {
  command = plan

  variables {
    scope = {
      type = "subscription"
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = length(azurerm_policy_set_definition.this) == 1 && length(azurerm_subscription_policy_assignment.this) == 1
    error_message = "A subscription scope must produce a subscription initiative and assignment."
  }
}

run "rejects_mismatched_scope" {
  command = plan

  variables {
    scope = {
      type = "subscription"
      id   = "/providers/Microsoft.Management/managementGroups/contoso-landingzones"
    }
  }

  expect_failures = [var.scope]
}
