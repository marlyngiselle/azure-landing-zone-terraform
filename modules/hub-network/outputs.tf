output "resource_group_name" {
  description = "Name of the hub resource group."
  value       = local.resource_group_name
}

output "virtual_network_id" {
  description = "Resource ID of the hub virtual network. Spokes peer to this."
  value       = azurerm_virtual_network.this.id
}

output "virtual_network_name" {
  description = "Name of the hub virtual network."
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of hub subnet name to subnet ID."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "firewall_private_ip" {
  description = "Private IP of Azure Firewall, used as next hop and DNS server by spokes. Null when the firewall is disabled."
  value       = local.deploy_firewall ? azurerm_firewall.this[0].ip_configuration[0].private_ip_address : null
}

output "firewall_policy_id" {
  description = "Resource ID of the firewall policy, to attach rule collection groups from workload pipelines. Null when the firewall is disabled."
  value       = one(azurerm_firewall_policy.this[*].id)
}

output "bastion_host_id" {
  description = "Resource ID of Azure Bastion, or null when disabled."
  value       = one(azurerm_bastion_host.this[*].id)
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone name to zone ID, for private endpoint DNS zone groups."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}
