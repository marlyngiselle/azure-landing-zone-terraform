output "subscription_id" {
  description = "Subscription GUID of the landing zone."
  value       = local.r.subscription_id
}

output "name_token" {
  description = "Name token (<workload>-<environment>-<region>) used for every resource in this landing zone."
  value       = local.token
}

output "resource_group_ids" {
  description = "Map of resource group key to resource group ID."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.id }
}

output "virtual_network_id" {
  description = "Spoke virtual network ID, or null when the request has no network."
  value       = one(module.spoke[*].virtual_network_id)
}

output "subnet_ids" {
  description = "Map of subnet key to subnet ID (empty when the request has no network)."
  value       = try(module.spoke[0].subnet_ids, {})
}

output "role_assignment_ids" {
  description = "Map of role assignment key (principal|role|scope) to assignment ID."
  value       = { for k, ra in azurerm_role_assignment.this : k => ra.id }
}

output "tags" {
  description = "Effective tags applied to the landing zone resources."
  value       = local.tags
}
