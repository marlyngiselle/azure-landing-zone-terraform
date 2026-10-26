# Naming and tagging

## Naming

Every resource name is built from a short type prefix and a name token:

```
<type>-<workload>-<environment>-<region>[-<suffix>]
```

| Segment | Values | Example |
|---------|--------|---------|
| `type` | Abbreviations from the Cloud Adoption Framework | `vnet`, `rg` |
| `workload` | 2 to 16 lowercase alphanumerics, from the request `name` | `payments` |
| `environment` | `dev`, `tst`, `prd` | `prd` |
| `region` | Short region code | `weu` |
| `suffix` | Optional role inside the workload | `app`, `network` |

### Type prefixes used by the modules

| Resource | Prefix | Example |
|----------|--------|---------|
| Resource group | `rg` | `rg-payments-prd-weu-app` |
| Virtual network | `vnet` | `vnet-hub-prd-weu` |
| Subnet | `snet` | `snet-app` |
| Network security group | `nsg` | `nsg-payments-prd-weu-app` |
| Route table | `rt` | `rt-payments-prd-weu` |
| VNet peering | `peer` | `peer-vnet-payments-prd-weu-to-vnet-hub-prd-weu` |
| Azure Firewall | `afw` | `afw-hub-prd-weu` |
| Firewall policy | `afwp` | `afwp-hub-prd-weu` |
| Azure Bastion | `bas` | `bas-hub-prd-weu` |
| Public IP | `pip-<parent>` | `pip-afw-hub-prd-weu` |
| Log Analytics workspace | `log` | `log-mgmt-prd-weu` |
| Action group | `ag` | `ag-mgmt-prd-weu` |
| Budget | `budget` | `budget-payments-prd-weu` |

Names Azure imposes (`AzureFirewallSubnet`, `AzureBastionSubnet`, `GatewaySubnet`, `privatelink.*` zones) are kept as is.

### Region codes

| Region | Code | Region | Code |
|--------|------|--------|------|
| westeurope | `weu` | uksouth | `uks` |
| northeurope | `neu` | eastus | `eus` |
| francecentral | `frc` | eastus2 | `eus2` |
| germanywestcentral | `gwc` | westus3 | `wus3` |
| swedencentral | `sdc` | switzerlandnorth | `szn` |

Unknown regions fall back to the full region name, so a new region never blocks a request.

### Why names are built, not chosen

Name tokens are validated by regular expression in every module. Teams pick a workload name and an environment, the modules build everything else. That removes the most common review comment ("rename this") and makes resources sortable and searchable by workload across subscriptions.

## Tagging

| Tag | Source | Enforced by policy | Purpose |
|-----|--------|--------------------|---------|
| `owner` | Request `owner` (team distribution list) | Yes | Who gets paged and who approves changes |
| `cost-center` | Request `cost_center` | Yes | Chargeback and showback |
| `environment` | Request `environment` | Yes | Cost reports, policy exemptions, alert routing |
| `workload` | Request `name` | Yes | Grouping across subscriptions |
| `data-classification` | Request `data_classification` | Yes | Drives security reviews and backup policy |
| `managed-by` | Always `terraform` | No | Tells humans not to fix things in the portal |
| `service-tier` and others | Request `tags` | No | Free-form, owned by the team |

Rules:

1. Tag keys are lowercase kebab case. Values are lowercase where they are enumerations.
2. Mandatory tags are derived from request fields and always win over free-form tags. A team cannot accidentally (or deliberately) set `owner` to something else through `tags`.
3. The [policy baseline](../modules/policy-baseline) requires the same five tags on every resource, so anything created outside Terraform is caught too.
4. Owners are team addresses, never individuals. People change teams; distribution lists stay.
