# policy-baseline

A small, opinionated security baseline as code: four custom policy definitions stored as JSON, grouped into one initiative and assigned at management group or subscription scope.

| Control | Default effect | Definition |
|---------|----------------|------------|
| Allowed locations | `Deny` | [`policies/allowed-locations.json`](policies/allowed-locations.json) |
| Required tags (one reference per tag) | `Deny` | [`policies/require-tag.json`](policies/require-tag.json) |
| No public IP on network interfaces | `Deny` | [`policies/deny-public-ip-on-nic.json`](policies/deny-public-ip-on-nic.json) |
| Diagnostic settings to Log Analytics | `AuditIfNotExists` | [`policies/require-diagnostic-settings.json`](policies/require-diagnostic-settings.json) |

## Usage

```hcl
module "policy" {
  source = "../../modules/policy-baseline"

  scope = {
    type = "management_group"
    id   = "/providers/Microsoft.Management/managementGroups/contoso-landingzones"
  }

  allowed_locations = ["westeurope", "northeurope"]

  # Brownfield rollout: report first, enforce later.
  effects    = { required_tags = "Audit" }
  assignment = { enforce = true }
}
```

## Behaviour

- Definitions are plain Azure Policy JSON. Adding a control means adding a file under `policies/` and a reference in `main.tf`; the JSON can be tested in the portal or with the Azure CLI as is.
- Effects are initiative parameters, so moving from `Audit` to `Deny` is a one-line change on the assignment, without touching definitions.
- Each control carries a non-compliance message that tells the engineer what to do instead.
- `assignment.enforce = false` puts the assignment in `DoNotEnforce` mode: compliance is evaluated, nothing is blocked.
- No control uses `DeployIfNotExists` or `Modify`, so the assignment needs no managed identity and no role assignment.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `scope` | `object` | n/a | `type` (`management_group` or `subscription`) and matching `id`, validated together. |
| `name_prefix` | `string` | `"alz"` | Prefix for definition and initiative names. |
| `allowed_locations` | `list(string)` | n/a | Approved regions. |
| `required_tags` | `set(string)` | `owner`, `cost-center`, `environment`, `workload`, `data-classification` | Mandatory tags. |
| `diagnostic_resource_types` | `list(string)` | firewall, Bastion, NSG, App Gateway, Key Vault, Storage, SQL DB, AKS | Types audited for diagnostics. |
| `effects` | `object` | `{}` | `allowed_locations`, `required_tags`, `deny_public_ip_nic` (`Audit`, `Deny`, `Disabled`) and `diagnostic_settings` (`AuditIfNotExists`, `Disabled`). |
| `assignment` | `object` | `{}` | `name` (24 chars max), `display_name`, `enforce` (`true`), `not_scopes`, `location`. |

## Outputs

| Name | Description |
|------|-------------|
| `policy_definition_ids` | Definition key to ID. |
| `policy_set_definition_id` | Initiative ID. |
| `policy_assignment_id` | Assignment ID. |

## Tests

`terraform test` checks both scopes and the scope validation with a mocked provider.
