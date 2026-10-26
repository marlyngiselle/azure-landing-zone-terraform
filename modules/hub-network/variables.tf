variable "name" {
  description = "Name token used to build resource names, following <workload>-<environment>-<region> (for example `hub-prd-weu`)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+){1,4}$", var.name))
    error_message = "name must be lowercase alphanumeric segments separated by hyphens, for example hub-prd-weu."
  }
}

variable "location" {
  description = "Azure region for the hub."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for the hub. Created by the module when `create_resource_group` is true."
  type        = string
}

variable "create_resource_group" {
  description = "Create the resource group. Set to false to deploy into an existing resource group."
  type        = bool
  default     = true
}

variable "address_space" {
  description = "Address space of the hub virtual network. A /22 or larger leaves room for firewall, Bastion, gateway and shared services."
  type        = list(string)

  validation {
    condition     = length(var.address_space) > 0 && alltrue([for cidr in var.address_space : can(cidrnetmask(cidr))])
    error_message = "address_space must contain at least one valid IPv4 CIDR."
  }
}

variable "subnets" {
  description = <<-EOT
    Address prefixes for the platform subnets. Leave a prefix null to skip that subnet.
    The firewall subnet needs at least a /26, Bastion at least a /26 and the gateway at least a /27.
  EOT
  type = object({
    firewall = optional(string)
    bastion  = optional(string)
    gateway  = optional(string)
    shared   = optional(string)
  })

  validation {
    condition     = alltrue([for cidr in values(var.subnets) : cidr == null || can(cidrnetmask(cidr))])
    error_message = "Every subnet prefix must be null or a valid IPv4 CIDR."
  }

  validation {
    condition     = var.subnets.firewall == null || tonumber(split("/", coalesce(var.subnets.firewall, "0.0.0.0/26"))[1]) <= 26
    error_message = "The firewall subnet must be /26 or larger."
  }

  validation {
    condition     = var.subnets.bastion == null || tonumber(split("/", coalesce(var.subnets.bastion, "0.0.0.0/26"))[1]) <= 26
    error_message = "The Bastion subnet must be /26 or larger."
  }
}

variable "firewall" {
  description = "Azure Firewall settings. When `enabled` is false no firewall, firewall policy or public IP is created."
  type = object({
    enabled                  = optional(bool, true)
    sku_tier                 = optional(string, "Standard")
    zones                    = optional(list(string), ["1", "2", "3"])
    threat_intelligence_mode = optional(string, "Deny")
    dns_proxy_enabled        = optional(bool, true)
    dns_servers              = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall.sku_tier)
    error_message = "firewall.sku_tier must be Standard or Premium. Basic is not supported because it lacks DNS proxy and needs a forced-tunnelling management subnet."
  }

  validation {
    condition     = contains(["Off", "Alert", "Deny"], var.firewall.threat_intelligence_mode)
    error_message = "firewall.threat_intelligence_mode must be Off, Alert or Deny."
  }
}

variable "bastion" {
  description = "Azure Bastion settings. Requires `subnets.bastion` when enabled."
  type = object({
    enabled            = optional(bool, false)
    sku                = optional(string, "Standard")
    zones              = optional(list(string), ["1", "2", "3"])
    tunneling_enabled  = optional(bool, true)
    copy_paste_enabled = optional(bool, true)
  })
  default = {}

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.bastion.sku)
    error_message = "bastion.sku must be Basic, Standard or Premium."
  }
}

variable "private_dns_zones" {
  description = "Private DNS zones hosted in the hub and linked to the hub VNet. Defaults cover the most common PaaS private endpoints."
  type        = set(string)
  default = [
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.dfs.core.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.database.windows.net",
    "privatelink.postgres.database.azure.com",
    "privatelink.azurecr.io",
    "privatelink.servicebus.windows.net",
    "privatelink.azurewebsites.net",
    "privatelink.monitor.azure.com",
  ]
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace that receives firewall and Bastion diagnostics. Diagnostics are skipped when null."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
