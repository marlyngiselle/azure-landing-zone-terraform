output "hub_firewall_private_ip" {
  description = "Next hop for spoke egress."
  value       = module.hub.firewall_private_ip
}

output "policy_assignment_id" {
  description = "Baseline initiative assignment on the landing zones management group."
  value       = module.policy.policy_assignment_id
}

output "landing_zone" {
  description = "What was vended for the current request."
  value = {
    name_token         = module.landing_zone.name_token
    subscription_id    = module.landing_zone.subscription_id
    resource_group_ids = module.landing_zone.resource_group_ids
    virtual_network_id = module.landing_zone.virtual_network_id
    subnet_ids         = module.landing_zone.subnet_ids
  }
}
