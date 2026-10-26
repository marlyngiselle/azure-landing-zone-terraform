output "diagnostic_setting_ids" {
  description = "Map of target key to diagnostic setting ID."
  value       = { for k, d in azurerm_monitor_diagnostic_setting.this : k => d.id }
}
