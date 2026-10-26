output "policy_definition_ids" {
  description = "Map of custom policy definition key to definition ID."
  value       = { for k, d in azurerm_policy_definition.this : k => d.id }
}

output "policy_set_definition_id" {
  description = "Resource ID of the baseline initiative."
  value       = local.set_definition_id
}

output "policy_assignment_id" {
  description = "Resource ID of the initiative assignment."
  value       = local.is_management_group ? azurerm_management_group_policy_assignment.this[0].id : azurerm_subscription_policy_assignment.this[0].id
}
