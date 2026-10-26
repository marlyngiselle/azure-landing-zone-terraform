variable "request" {
  description = <<-EOT
    A landing zone request, typically decoded from a YAML file with yamldecode().
    See examples/full/requests/ for the reference schema. The request describes
    what the team needs; the module decides how it is built.
  EOT
  type = object({
    name                = string
    environment         = string
    location            = string
    subscription_id     = string
    management_group_id = optional(string)
    owner               = string
    cost_center         = string
    data_classification = optional(string, "internal")
    resource_groups     = optional(list(string), ["app"])
    network = optional(object({
      address_space = list(string)
      subnets = optional(map(object({
        address_prefixes  = list(string)
        private_endpoints = optional(bool, false)
        service_endpoints = optional(list(string), [])
      })), {})
    }))
    role_assignments = optional(list(object({
      principal_id = string
      role         = string
      scope        = optional(string, "subscription")
      description  = optional(string)
    })), [])
    budget = optional(object({
      amount         = number
      start_date     = string
      contact_emails = list(string)
      thresholds     = optional(list(number), [80, 100])
    }))
    tags = optional(map(string), {})
  })

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,15}$", var.request.name))
    error_message = "request.name must be 2 to 16 lowercase alphanumeric characters starting with a letter."
  }

  validation {
    condition     = contains(["dev", "tst", "prd"], var.request.environment)
    error_message = "request.environment must be dev, tst or prd."
  }

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.request.subscription_id))
    error_message = "request.subscription_id must be a subscription GUID."
  }

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.request.owner))
    error_message = "request.owner must be an email address (a team distribution list is preferred over a person)."
  }

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.request.data_classification)
    error_message = "request.data_classification must be public, internal, confidential or restricted."
  }

  validation {
    condition     = alltrue([for rg in var.request.resource_groups : can(regex("^[a-z][a-z0-9]{1,15}$", rg))]) && !contains(var.request.resource_groups, "network")
    error_message = "request.resource_groups entries must be short lowercase names; 'network' is reserved for the spoke."
  }

  validation {
    condition = alltrue([
      for ra in var.request.role_assignments :
      !contains(["Owner", "User Access Administrator", "Role Based Access Control Administrator"], ra.role)
    ])
    error_message = "Privileged roles (Owner, User Access Administrator, RBAC Administrator) cannot be self-served. Raise a platform change instead."
  }

  validation {
    condition = alltrue([
      for ra in var.request.role_assignments :
      ra.scope == "subscription" || (startswith(ra.scope, "rg:") && contains(concat(var.request.resource_groups, ["network"]), trimprefix(ra.scope, "rg:")))
    ])
    error_message = "role_assignments[].scope must be 'subscription' or 'rg:<name>' where <name> is a requested resource group."
  }

  validation {
    condition     = var.request.budget == null || try(var.request.budget.amount > 0 && can(regex("^\\d{4}-\\d{2}-01T00:00:00Z$", var.request.budget.start_date)), false)
    error_message = "request.budget needs a positive amount and a start_date on the first day of a month (YYYY-MM-01T00:00:00Z)."
  }
}

variable "hub" {
  description = "Hub network the spoke peers with. Ignored when the request has no network block."
  type = object({
    virtual_network_id  = string
    firewall_private_ip = optional(string)
  })
}

variable "log_analytics_workspace_id" {
  description = "Platform Log Analytics workspace for network diagnostics. Diagnostics are skipped when null."
  type        = string
  default     = null
}

variable "budget_action_group_id" {
  description = "Optional action group notified by the budget in addition to the request contacts (for example the FinOps team)."
  type        = string
  default     = null
}

variable "default_tags" {
  description = "Platform tags merged under the request tags. Mandatory tags derived from the request always win."
  type        = map(string)
  default     = {}
}
