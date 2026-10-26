resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.targets

  name                           = var.name
  target_resource_id             = each.value.resource_id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = each.value.destination_dedicated ? "Dedicated" : null

  dynamic "enabled_log" {
    for_each = toset(each.value.log_category_groups)

    content {
      category_group = enabled_log.value
    }
  }

  dynamic "enabled_log" {
    for_each = toset(each.value.log_categories)

    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(each.value.metric_categories)

    content {
      category = enabled_metric.value
    }
  }
}
