locals {
  request = yamldecode(file("${path.module}/${var.request_file}"))

  # Every request in the catalogue, used for cross-request guardrails below.
  all_requests = {
    for f in fileset("${path.module}/requests", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/requests/${f}"))
  }

  platform_tags = {
    owner               = "platform-team@contoso.com"
    cost-center         = "cc-platform"
    environment         = "prd"
    workload            = "platform"
    data-classification = "internal"
  }
}

check "landing_zone_names_are_unique" {
  assert {
    condition = length(distinct([
      for r in values(local.all_requests) : "${r.name}-${r.environment}"
    ])) == length(local.all_requests)
    error_message = "Two requests share the same name and environment."
  }
}

check "landing_zone_subscriptions_are_unique" {
  assert {
    condition = length(distinct([
      for r in values(local.all_requests) : r.subscription_id
    ])) == length(local.all_requests)
    error_message = "Two requests target the same subscription."
  }
}

# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------

module "management" {
  source = "../../modules/management"

  name                  = "mgmt-prd-weu"
  location              = var.location
  resource_group_name   = "rg-mgmt-prd-weu"
  log_analytics         = { retention_in_days = 180 }
  alert_email_receivers = var.platform_alert_emails

  budgets = {
    platform-monthly = {
      amount     = 6000
      start_date = "2026-11-01T00:00:00Z"
    }
  }

  tags = local.platform_tags
}

module "hub" {
  source = "../../modules/hub-network"

  name                = "hub-prd-weu"
  location            = var.location
  resource_group_name = "rg-hub-prd-weu"
  address_space       = ["10.100.0.0/22"]

  subnets = {
    firewall = "10.100.0.0/26"
    bastion  = "10.100.0.64/26"
    gateway  = "10.100.0.128/27"
    shared   = "10.100.1.0/24"
  }

  firewall = {
    enabled  = true
    sku_tier = "Premium"
  }

  bastion = {
    enabled = true
    sku     = "Standard"
  }

  log_analytics_workspace_id = module.management.log_analytics_workspace_id
  tags                       = local.platform_tags
}

module "policy" {
  source = "../../modules/policy-baseline"

  scope = {
    type = "management_group"
    id   = var.landing_zones_management_group_id
  }

  allowed_locations = ["westeurope", "northeurope"]
}

# ---------------------------------------------------------------------------
# Landing zone, vended from a YAML request
# ---------------------------------------------------------------------------

module "landing_zone" {
  source = "../../modules/subscription-vending"

  providers = {
    azurerm     = azurerm.landing_zone
    azurerm.hub = azurerm
  }

  request = local.request

  hub = {
    virtual_network_id  = module.hub.virtual_network_id
    firewall_private_ip = module.hub.firewall_private_ip
  }

  log_analytics_workspace_id = module.management.log_analytics_workspace_id
  budget_action_group_id     = module.management.action_group_id
  default_tags               = { platform-version = "1.0" }
}
