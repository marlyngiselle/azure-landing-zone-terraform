output "virtual_network_id" {
  description = "Resource ID of the spoke virtual network."
  value       = azurerm_virtual_network.this.id
}

output "virtual_network_name" {
  description = "Name of the spoke virtual network."
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of subnet key to subnet ID."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "network_security_group_ids" {
  description = "Map of subnet key to NSG ID."
  value       = { for k, n in azurerm_network_security_group.this : k => n.id }
}

output "route_table_id" {
  description = "Resource ID of the spoke route table, or null when the hub has no firewall."
  value       = one(azurerm_route_table.this[*].id)
}
