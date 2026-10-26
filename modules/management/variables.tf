variable "name" {
  description = "Name token used to build resource names, following <workload>-<environment>-<region> (for example `mgmt-prd-weu`)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+){1,4}$", var.name))
    error_message = "name must be lowercase alphanumeric segments separated by hyphens, for example mgmt-prd-weu."
  }
}

variable "location" {
  description = "Azure region for all resources created by this module."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that holds the management resources. Created by the module when `create_resource_group` is true."
  type        = string
}

variable "create_resource_group" {
  description = "Create the resource group. Set to false to deploy into an existing resource group."
  type        = bool
  default     = true
}

variable "log_analytics" {
  description = "Log Analytics workspace settings. `daily_quota_gb = -1` means no cap."
  type = object({
    sku                   = optional(string, "PerGB2018")
    retention_in_days     = optional(number, 90)
    daily_quota_gb        = optional(number, -1)
    internet_query        = optional(bool, true)
    internet_ingestion    = optional(bool, true)
    local_auth_enabled    = optional(bool, false)
    allow_resource_access = optional(bool, true)
  })
  default = {}

  validation {
    condition     = var.log_analytics.retention_in_days >= 30 && var.log_analytics.retention_in_days <= 730
    error_message = "log_analytics.retention_in_days must be between 30 and 730."
  }

  validation {
    condition     = contains(["PerGB2018", "CapacityReservation"], var.log_analytics.sku)
    error_message = "log_analytics.sku must be PerGB2018 or CapacityReservation."
  }
}

variable "alert_email_receivers" {
  description = "Email receivers for the platform action group, keyed by a short receiver name."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for email in values(var.alert_email_receivers) : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))])
    error_message = "Every alert_email_receivers value must be a valid email address."
  }
}

variable "budgets" {
  description = <<-EOT
    Monthly cost budgets scoped to the current subscription, keyed by budget name.
    Notifications fire at each threshold (percentage of `amount`). Use `Forecasted`
    thresholds to warn before the money is spent, `Actual` to confirm it was.
  EOT
  type = map(object({
    amount     = number
    start_date = string
    end_date   = optional(string)
    thresholds = optional(list(object({
      percentage = number
      type       = optional(string, "Actual")
      })), [
      { percentage = 80, type = "Forecasted" },
      { percentage = 100, type = "Actual" },
    ])
    contact_emails = optional(list(string), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for b in values(var.budgets) : b.amount > 0])
    error_message = "Every budget amount must be greater than zero."
  }

  validation {
    condition     = alltrue([for b in values(var.budgets) : can(regex("^\\d{4}-\\d{2}-01T00:00:00Z$", b.start_date))])
    error_message = "Budget start_date must be the first day of a month in RFC3339 format, for example 2026-11-01T00:00:00Z."
  }

  validation {
    condition = alltrue(flatten([
      for b in values(var.budgets) : [for t in b.thresholds : contains(["Actual", "Forecasted"], t.type) && t.percentage > 0 && t.percentage <= 1000]
    ]))
    error_message = "Budget thresholds must use type Actual or Forecasted and a percentage between 1 and 1000."
  }
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
