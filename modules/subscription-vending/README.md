# subscription-vending

Turns a landing zone request into a ready-to-use subscription: management group placement, resource group layout, a spoke peered to the hub, least-privilege role assignments, a budget and mandatory tags.

The request is a plain object, designed to be decoded from a YAML file reviewed in a pull request:

```hcl
locals {
  request = yamldecode(file("${path.module}/requests/payments-prd.yaml"))
}

module "landing_zone" {
  source = "../../modules/subscription-vending"

  providers = {
    azurerm     = azurerm.landing_zone # provider pointing at request.subscription_id
    azurerm.hub = azurerm              # connectivity subscription
  }

  request = local.request

  hub = {
    virtual_network_id  = module.hub.virtual_network_id
    firewall_private_ip = module.hub.firewall_private_ip
  }

  log_analytics_workspace_id = module.management.log_analytics_workspace_id
  budget_action_group_id     = module.management.action_group_id
}
```

## Request schema

```yaml
name: payments                # 2-16 lowercase chars, becomes the workload token
environment: prd              # dev | tst | prd
location: westeurope
subscription_id: 11111111-1111-1111-1111-111111111111
management_group_id: /providers/Microsoft.Management/managementGroups/contoso-landingzones-corp  # optional
owner: team-payments@contoso.com
cost_center: cc-4100
data_classification: confidential   # public | internal (default) | confidential | restricted
resource_groups: [app, data]        # 'network' is reserved and added when network is set
network:                            # optional; omit for PaaS-only landing zones
  address_space: [10.110.0.0/22]
  subnets:
    app:  { address_prefixes: [10.110.0.0/24] }
    data: { address_prefixes: [10.110.1.0/26], private_endpoints: true }
role_assignments:
  - principal_id: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
    role: Contributor
    scope: rg:app                   # subscription | rg:<name>
budget:                             # optional
  amount: 3500
  start_date: "2026-11-01T00:00:00Z"
  contact_emails: [team-payments@contoso.com]
  thresholds: [50, 80, 100]         # actual spend; a 100% forecast alert is always added
tags:
  service-tier: tier-1
```

## Guardrails built into the schema

- `Owner`, `User Access Administrator` and `Role Based Access Control Administrator` are rejected at plan time. Privileged access is a platform change, not a self-service request.
- Role assignment scopes must reference a resource group the request actually creates.
- Mandatory tags (`workload`, `environment`, `owner`, `cost-center`, `data-classification`, `managed-by`) are derived from the request fields and always override free-form tags, so they match the policy baseline by construction.
- Names follow `<type>-<workload>-<env>-<region>[-<suffix>]`, see [naming and tagging](../../docs/naming-and-tagging.md).

## Subscription creation

The module lands an existing subscription; it does not create it. Subscription creation depends on the billing agreement (EA, MCA, CSP) and on approvals that sit outside Terraform. See [ADR 0004](../../docs/adr/0004-subscription-vending-from-requests.md).

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `request` | `object` | n/a | Landing zone request (schema above), validated field by field. |
| `hub` | `object` | n/a | `virtual_network_id` and optional `firewall_private_ip`. |
| `log_analytics_workspace_id` | `string` | `null` | Platform workspace for network diagnostics. |
| `budget_action_group_id` | `string` | `null` | Extra action group notified by the budget. |
| `default_tags` | `map(string)` | `{}` | Platform tags merged under request tags. |

## Outputs

| Name | Description |
|------|-------------|
| `subscription_id` | Subscription GUID. |
| `name_token` | `<workload>-<env>-<region>` token used for every name. |
| `resource_group_ids` | Resource group key to ID. |
| `virtual_network_id` | Spoke VNet ID, or `null`. |
| `subnet_ids` | Subnet key to ID. |
| `role_assignment_ids` | Assignment key (`principal_id`, role and scope joined by `\|`) to assignment ID. |
| `tags` | Effective tags. |

## Tests

`terraform test` covers the layout, tag precedence, the PaaS-only path and both role guardrails, with mocked providers.
