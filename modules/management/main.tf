data "azurerm_subscription" "current" {}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name
  tags                = merge({ managed-by = "terraform" }, var.tags)
}

resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name}"
  location            = var.location
  resource_group_name = local.resource_group_name

  sku                             = var.log_analytics.sku
  retention_in_days               = var.log_analytics.retention_in_days
  daily_quota_gb                  = var.log_analytics.daily_quota_gb
  internet_query_enabled          = var.log_analytics.internet_query
  internet_ingestion_enabled      = var.log_analytics.internet_ingestion
  local_authentication_enabled    = var.log_analytics.local_auth_enabled
  allow_resource_only_permissions = var.log_analytics.allow_resource_access

  tags = local.tags
}

resource "azurerm_monitor_action_group" "platform" {
  count = length(var.alert_email_receivers) > 0 ? 1 : 0

  name                = "ag-${var.name}"
  resource_group_name = local.resource_group_name
  short_name          = substr(replace("ag${var.name}", "-", ""), 0, 12)

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers

    content {
      name                    = email_receiver.key
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = local.tags
}

resource "azurerm_consumption_budget_subscription" "this" {
  for_each = var.budgets

  name            = each.key
  subscription_id = data.azurerm_subscription.current.id
  amount          = each.value.amount
  time_grain      = "Monthly"

  time_period {
    start_date = each.value.start_date
    end_date   = each.value.end_date
  }

  dynamic "notification" {
    for_each = each.value.thresholds

    content {
      enabled        = true
      operator       = "GreaterThanOrEqualTo"
      threshold      = notification.value.percentage
      threshold_type = notification.value.type
      contact_emails = each.value.contact_emails
      contact_groups = azurerm_monitor_action_group.platform[*].id
    }
  }

  lifecycle {
    # Azure normalises the start date once the budget exists; ignoring it avoids a perpetual diff.
    ignore_changes = [time_period[0].start_date]
  }
}
