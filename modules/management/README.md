# management

Platform observability and cost guardrails: one Log Analytics workspace, a platform action group and subscription budgets. Ships with a [`diagnostic-settings`](modules/diagnostic-settings) submodule that every other module uses to send logs and metrics to the workspace.

## Usage

```hcl
module "management" {
  source = "../../modules/management"

  name                = "mgmt-prd-weu"
  location            = "westeurope"
  resource_group_name = "rg-mgmt-prd-weu"

  log_analytics = { retention_in_days = 180 }

  alert_email_receivers = {
    platform-oncall = "platform-oncall@contoso.com"
  }

  budgets = {
    platform-monthly = {
      amount     = 6000
      start_date = "2026-11-01T00:00:00Z"
    }
  }

  tags = { owner = "platform-team@contoso.com", cost-center = "cc-platform" }
}
```

## Behaviour

- Local (shared key) authentication on the workspace is disabled by default; agents and users authenticate with Entra ID.
- Budgets default to two notifications: 80% forecasted (early warning) and 100% actual. Every notification also targets the action group when one exists.
- The budget `start_date` is ignored after creation, because Azure normalises it and would otherwise produce a permanent diff.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | n/a | Name token `<workload>-<env>-<region>`, validated. |
| `location` | `string` | n/a | Azure region. |
| `resource_group_name` | `string` | n/a | Resource group for the management resources. |
| `create_resource_group` | `bool` | `true` | Create the resource group or reuse an existing one. |
| `log_analytics` | `object` | `{}` | `sku`, `retention_in_days` (30 to 730, default 90), `daily_quota_gb`, `internet_query`, `internet_ingestion`, `local_auth_enabled` (default `false`), `allow_resource_access`. |
| `alert_email_receivers` | `map(string)` | `{}` | Receiver name to email. Creates the action group when not empty. |
| `budgets` | `map(object)` | `{}` | Monthly budgets on the current subscription: `amount`, `start_date`, `end_date`, `thresholds`, `contact_emails`. |
| `tags` | `map(string)` | `{}` | Tags for every resource. `managed-by = terraform` is always added. |

## Outputs

| Name | Description |
|------|-------------|
| `resource_group_name` | Resource group holding the management resources. |
| `log_analytics_workspace_id` | Workspace resource ID, consumed by every diagnostic setting. |
| `log_analytics_workspace_name` | Workspace name. |
| `log_analytics_workspace_customer_id` | Workspace (customer) ID. |
| `action_group_id` | Platform action group ID, or `null`. |
| `budget_ids` | Budget name to budget ID. |

## Submodule: diagnostic-settings

```hcl
module "diagnostics" {
  source = "../../modules/management/modules/diagnostic-settings"

  log_analytics_workspace_id = module.management.log_analytics_workspace_id
  targets = {
    keyvault = { resource_id = azurerm_key_vault.this.id }
    appgw    = { resource_id = azurerm_application_gateway.this.id, destination_dedicated = true }
  }
}
```

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `targets` | `map(object)` | n/a | Static key to `resource_id`, `log_category_groups` (default `["allLogs"]`), `log_categories`, `metric_categories` (default `["AllMetrics"]`), `destination_dedicated`. |
| `log_analytics_workspace_id` | `string` | n/a | Destination workspace. |
| `name` | `string` | `"diag-to-platform-law"` | Diagnostic setting name on each target. |

| Output | Description |
|--------|-------------|
| `diagnostic_setting_ids` | Target key to diagnostic setting ID. |

Keys must be static so that `for_each` is known at plan time, even when resource IDs are not.
