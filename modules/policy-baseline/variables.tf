variable "scope" {
  description = <<-EOT
    Where the definitions live and the initiative is assigned.
    `type` is `management_group` or `subscription`; `id` is the full resource ID
    (`/providers/Microsoft.Management/managementGroups/<name>` or `/subscriptions/<guid>`).
    For subscription scope, the azurerm provider must target that same subscription.
  EOT
  type = object({
    type = string
    id   = string
  })

  validation {
    condition     = contains(["management_group", "subscription"], var.scope.type)
    error_message = "scope.type must be management_group or subscription."
  }

  validation {
    condition = (
      var.scope.type == "management_group"
      ? can(regex("(?i)^/providers/Microsoft.Management/managementGroups/[^/]+$", var.scope.id))
      : can(regex("(?i)^/subscriptions/[0-9a-f-]{36}$", var.scope.id))
    )
    error_message = "scope.id must be a management group ID or a subscription ID matching scope.type."
  }
}

variable "name_prefix" {
  description = "Prefix for policy definition and initiative names, to avoid collisions with other baselines in the same scope."
  type        = string
  default     = "alz"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.name_prefix))
    error_message = "name_prefix must be 2 to 8 lowercase alphanumeric characters."
  }
}

variable "allowed_locations" {
  description = "Regions where resources may be deployed."
  type        = list(string)

  validation {
    condition     = length(var.allowed_locations) > 0
    error_message = "allowed_locations must contain at least one region."
  }
}

variable "required_tags" {
  description = "Tags that every taggable resource must carry. One policy reference is generated per tag."
  type        = set(string)
  default     = ["owner", "cost-center", "environment", "workload", "data-classification"]
}

variable "diagnostic_resource_types" {
  description = "Resource types audited for missing diagnostic settings."
  type        = list(string)
  default = [
    "Microsoft.Network/azureFirewalls",
    "Microsoft.Network/bastionHosts",
    "Microsoft.Network/networkSecurityGroups",
    "Microsoft.Network/applicationGateways",
    "Microsoft.KeyVault/vaults",
    "Microsoft.Storage/storageAccounts",
    "Microsoft.Sql/servers/databases",
    "Microsoft.ContainerService/managedClusters",
  ]
}

variable "effects" {
  description = "Effect per control. Start with Audit in brownfield scopes, then move to Deny once compliance is clean."
  type = object({
    allowed_locations   = optional(string, "Deny")
    required_tags       = optional(string, "Deny")
    deny_public_ip_nic  = optional(string, "Deny")
    diagnostic_settings = optional(string, "AuditIfNotExists")
  })
  default = {}

  validation {
    condition = alltrue([
      for e in [var.effects.allowed_locations, var.effects.required_tags, var.effects.deny_public_ip_nic] :
      contains(["Audit", "Deny", "Disabled"], e)
    ])
    error_message = "allowed_locations, required_tags and deny_public_ip_nic effects must be Audit, Deny or Disabled."
  }

  validation {
    condition     = contains(["AuditIfNotExists", "Disabled"], var.effects.diagnostic_settings)
    error_message = "effects.diagnostic_settings must be AuditIfNotExists or Disabled."
  }
}

variable "assignment" {
  description = "Assignment settings. `enforce = false` evaluates compliance without blocking deployments (DoNotEnforce)."
  type = object({
    name         = optional(string, "alz-baseline")
    display_name = optional(string, "Landing zone security baseline")
    enforce      = optional(bool, true)
    not_scopes   = optional(list(string), [])
    location     = optional(string)
  })
  default = {}

  validation {
    condition     = length(var.assignment.name) <= 24 && can(regex("^[a-z0-9-]+$", var.assignment.name))
    error_message = "assignment.name must be at most 24 lowercase alphanumeric characters or hyphens (management group limit)."
  }
}
