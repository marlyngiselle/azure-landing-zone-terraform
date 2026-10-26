output "log_analytics_workspace_id" {
  description = "Platform Log Analytics workspace."
  value       = module.management.log_analytics_workspace_id
}

output "hub_virtual_network_id" {
  description = "Hub virtual network."
  value       = module.hub.virtual_network_id
}

output "spoke_subnet_ids" {
  description = "Spoke subnets."
  value       = module.spoke.subnet_ids
}

output "policy_assignment_id" {
  description = "Baseline initiative assignment."
  value       = module.policy.policy_assignment_id
}
