output "resource_group_name" {
  description = "Name of the resource group holding the management resources."
  value       = local.resource_group_name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace. Pass this to the diagnostic-settings submodule and to other modules."
  value       = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "log_analytics_workspace_customer_id" {
  description = "Workspace (customer) ID used by agents and queries."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "action_group_id" {
  description = "Resource ID of the platform action group, or null when no receivers are configured."
  value       = one(azurerm_monitor_action_group.platform[*].id)
}

output "budget_ids" {
  description = "Map of budget name to budget resource ID."
  value       = { for k, b in azurerm_consumption_budget_subscription.this : k => b.id }
}
