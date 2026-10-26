locals {
  region_short = {
    westeurope         = "weu"
    northeurope        = "neu"
    francecentral      = "frc"
    germanywestcentral = "gwc"
    swedencentral      = "sdc"
    switzerlandnorth   = "szn"
    uksouth            = "uks"
    eastus             = "eus"
    eastus2            = "eus2"
    westus3            = "wus3"
  }

  r      = var.request
  region = lookup(local.region_short, local.r.location, local.r.location)
  token  = "${local.r.name}-${local.r.environment}-${local.region}"

  subscription_resource_id = "/subscriptions/${local.r.subscription_id}"

  # Mandatory tags are derived from the request and cannot be overridden by free-form tags.
  tags = merge(var.default_tags, local.r.tags, {
    workload            = local.r.name
    environment         = local.r.environment
    owner               = local.r.owner
    cost-center         = local.r.cost_center
    data-classification = local.r.data_classification
    managed-by          = "terraform"
  })

  resource_groups = merge(
    { for rg in local.r.resource_groups : rg => "rg-${local.token}-${rg}" },
    local.r.network == null ? {} : { network = "rg-${local.token}-network" },
  )

  role_assignments = {
    for ra in local.r.role_assignments :
    "${ra.principal_id}|${ra.role}|${ra.scope}" => ra
  }
}

resource "azurerm_management_group_subscription_association" "this" {
  count = local.r.management_group_id == null ? 0 : 1

  management_group_id = local.r.management_group_id
  subscription_id     = local.subscription_resource_id
}

resource "azurerm_resource_group" "this" {
  for_each = local.resource_groups

  name     = each.value
  location = local.r.location
  tags     = local.tags
}

module "spoke" {
  source = "../spoke-network"
  count  = local.r.network == null ? 0 : 1

  providers = {
    azurerm     = azurerm
    azurerm.hub = azurerm.hub
  }

  name                       = local.token
  location                   = local.r.location
  resource_group_name        = azurerm_resource_group.this["network"].name
  address_space              = local.r.network.address_space
  hub                        = var.hub
  log_analytics_workspace_id = var.log_analytics_workspace_id
  tags                       = local.tags

  subnets = {
    for k, s in local.r.network.subnets : k => {
      address_prefixes  = s.address_prefixes
      private_endpoints = s.private_endpoints
      service_endpoints = s.service_endpoints
    }
  }
}

resource "azurerm_role_assignment" "this" {
  for_each = local.role_assignments

  scope                = each.value.scope == "subscription" ? local.subscription_resource_id : azurerm_resource_group.this[trimprefix(each.value.scope, "rg:")].id
  role_definition_name = each.value.role
  principal_id         = each.value.principal_id
  description          = each.value.description
}

resource "azurerm_consumption_budget_subscription" "this" {
  count = local.r.budget == null ? 0 : 1

  name            = "budget-${local.token}"
  subscription_id = local.subscription_resource_id
  amount          = local.r.budget.amount
  time_grain      = "Monthly"

  time_period {
    start_date = local.r.budget.start_date
  }

  dynamic "notification" {
    for_each = toset(local.r.budget.thresholds)

    content {
      enabled        = true
      operator       = "GreaterThanOrEqualTo"
      threshold      = notification.value
      threshold_type = "Actual"
      contact_emails = local.r.budget.contact_emails
      contact_groups = var.budget_action_group_id == null ? [] : [var.budget_action_group_id]
    }
  }

  # Early warning before the month closes.
  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = local.r.budget.contact_emails
    contact_groups = var.budget_action_group_id == null ? [] : [var.budget_action_group_id]
  }

  lifecycle {
    ignore_changes = [time_period[0].start_date]
  }
}
