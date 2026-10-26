variable "platform_subscription_id" {
  description = "Subscription hosting the platform: Log Analytics, hub network and Azure Firewall."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.platform_subscription_id))
    error_message = "platform_subscription_id must be a subscription GUID."
  }
}

variable "landing_zones_management_group_id" {
  description = "Management group under which landing zone subscriptions live. The policy baseline is assigned here."
  type        = string
  default     = "/providers/Microsoft.Management/managementGroups/contoso-landingzones"
}

variable "location" {
  description = "Primary platform region."
  type        = string
  default     = "westeurope"
}

variable "request_file" {
  description = "Landing zone request to apply, relative to this directory."
  type        = string
  default     = "requests/payments-prd.yaml"

  validation {
    condition     = can(regex("^requests/[a-z0-9-]+\\.ya?ml$", var.request_file))
    error_message = "request_file must point to a YAML file under requests/."
  }
}

variable "platform_alert_emails" {
  description = "Receivers for platform alerts and budget notifications."
  type        = map(string)
  default = {
    platform-oncall = "platform-oncall@contoso.com"
    finops          = "finops@contoso.com"
  }
}
