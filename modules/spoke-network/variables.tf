variable "name" {
  description = "Name token used to build resource names, following <workload>-<environment>-<region> (for example `payments-prd-weu`)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+){1,4}$", var.name))
    error_message = "name must be lowercase alphanumeric segments separated by hyphens, for example payments-prd-weu."
  }
}

variable "location" {
  description = "Azure region for the spoke."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that holds the spoke network resources."
  type        = string
}

variable "address_space" {
  description = "Address space of the spoke virtual network. Must not overlap with the hub or any other spoke."
  type        = list(string)

  validation {
    condition     = length(var.address_space) > 0 && alltrue([for cidr in var.address_space : can(cidrnetmask(cidr))])
    error_message = "address_space must contain at least one valid IPv4 CIDR."
  }
}

variable "subnets" {
  description = <<-EOT
    Workload subnets keyed by short name (the subnet is named `snet-<key>`).
    Every subnet gets its own NSG. `route_to_firewall` attaches the spoke route table
    so that all egress is inspected by the hub firewall.
  EOT
  type = map(object({
    address_prefixes   = list(string)
    service_endpoints  = optional(list(string), [])
    private_endpoints  = optional(bool, false)
    route_to_firewall  = optional(bool, true)
    delegation_service = optional(string)
    delegation_actions = optional(list(string), [])
    security_rules = optional(list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_address_prefix      = string
      source_port_ranges         = optional(list(string), ["*"])
      destination_address_prefix = optional(string, "VirtualNetwork")
      destination_port_ranges    = list(string)
      description                = optional(string)
    })), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.subnets) : alltrue([for cidr in s.address_prefixes : can(cidrnetmask(cidr))])])
    error_message = "Every subnet address prefix must be a valid IPv4 CIDR."
  }

  validation {
    condition = alltrue(flatten([
      for s in values(var.subnets) : [
        for r in s.security_rules :
        r.priority >= 100 && r.priority <= 4000 &&
        contains(["Inbound", "Outbound"], r.direction) &&
        contains(["Allow", "Deny"], r.access) &&
        contains(["Tcp", "Udp", "Icmp", "Esp", "Ah", "*"], r.protocol)
      ]
    ]))
    error_message = "Security rules need a priority between 100 and 4000, direction Inbound/Outbound, access Allow/Deny and a valid protocol."
  }
}

variable "hub" {
  description = "Hub network to peer with. `firewall_private_ip` drives the default route and DNS; set it to null for a hub without a firewall."
  type = object({
    virtual_network_id  = string
    firewall_private_ip = optional(string)
    use_remote_gateways = optional(bool, false)
  })

  validation {
    condition     = can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$", var.hub.virtual_network_id))
    error_message = "hub.virtual_network_id must be a virtual network resource ID."
  }

  validation {
    condition     = var.hub.firewall_private_ip == null || can(cidrhost("${coalesce(var.hub.firewall_private_ip, "0.0.0.0")}/32", 0))
    error_message = "hub.firewall_private_ip must be null or a valid IPv4 address."
  }
}

variable "dns_servers" {
  description = "Custom DNS servers for the spoke. Defaults to the hub firewall (DNS proxy) when the firewall is present."
  type        = list(string)
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace for VNet and NSG diagnostics. Diagnostics are skipped when null."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
