variable "targets" {
  description = <<-EOT
    Resources to send diagnostics for, keyed by a stable, human-readable name
    (keys must be known at plan time; resource IDs may be unknown).
    Each target can override the log category groups and metric categories.
  EOT
  type = map(object({
    resource_id           = string
    log_category_groups   = optional(list(string), ["allLogs"])
    log_categories        = optional(list(string), [])
    metric_categories     = optional(list(string), ["AllMetrics"])
    destination_dedicated = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for t in values(var.targets) : startswith(lower(t.resource_id), "/subscriptions/")])
    error_message = "Every target resource_id must be a full Azure resource ID starting with /subscriptions/."
  }

  validation {
    condition = alltrue([
      for t in values(var.targets) : alltrue([for g in t.log_category_groups : contains(["allLogs", "audit"], g)])
    ])
    error_message = "log_category_groups only accepts allLogs and audit."
  }
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace that receives the diagnostics."
  type        = string
}

variable "name" {
  description = "Name of the diagnostic setting created on each target."
  type        = string
  default     = "diag-to-platform-law"
}
