# hub-network

The connectivity hub of a hub and spoke topology: hub VNet, Azure Firewall with a firewall policy, optional Azure Bastion, and private DNS zones for PaaS private endpoints.

## Usage

```hcl
module "hub" {
  source = "../../modules/hub-network"

  name                = "hub-prd-weu"
  location            = "westeurope"
  resource_group_name = "rg-hub-prd-weu"
  address_space       = ["10.100.0.0/22"]

  subnets = {
    firewall = "10.100.0.0/26"
    bastion  = "10.100.0.64/26"
    gateway  = "10.100.0.128/27"
    shared   = "10.100.1.0/24"
  }

  firewall = { enabled = true, sku_tier = "Premium" }
  bastion  = { enabled = true }

  log_analytics_workspace_id = module.management.log_analytics_workspace_id
}
```

## Behaviour

- Firewall is on by default, zone redundant, with threat intelligence in `Deny` mode and DNS proxy enabled so that spokes can use it as their DNS server. Premium adds IDPS in `Deny` mode.
- The firewall policy is created empty. Rule collection groups belong to the teams that own the flows; attach them through `firewall_policy_id`.
- Bastion is off by default. When on, tunnelling (native client) is enabled for Standard and Premium.
- Subnets use the names Azure requires (`AzureFirewallSubnet`, `AzureBastionSubnet`, `GatewaySubnet`). Default outbound access is disabled on every subnet. `snet-shared` gets an NSG.
- Private DNS zones are created and linked to the hub VNet only. Spokes resolve through the firewall DNS proxy, so there is a single resolution path to maintain.
- Diagnostics for the VNet, firewall (resource-specific tables) and Bastion go to Log Analytics when `log_analytics_workspace_id` is set.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | n/a | Name token `<workload>-<env>-<region>`, validated. |
| `location` | `string` | n/a | Azure region. |
| `resource_group_name` | `string` | n/a | Resource group for the hub. |
| `create_resource_group` | `bool` | `true` | Create the resource group or reuse an existing one. |
| `address_space` | `list(string)` | n/a | Hub address space, validated as CIDRs. |
| `subnets` | `object` | n/a | Optional prefixes for `firewall` (/26 or larger), `bastion` (/26 or larger), `gateway`, `shared`. Null skips the subnet. |
| `firewall` | `object` | `{}` | `enabled` (`true`), `sku_tier` (`Standard` or `Premium`), `zones`, `threat_intelligence_mode` (`Deny`), `dns_proxy_enabled` (`true`), `dns_servers`. |
| `bastion` | `object` | `{}` | `enabled` (`false`), `sku` (`Standard`), `zones`, `tunneling_enabled`, `copy_paste_enabled`. |
| `private_dns_zones` | `set(string)` | 12 common zones | Private DNS zones hosted in the hub (blob, file, queue, table, dfs, Key Vault, SQL, PostgreSQL, ACR, Service Bus, App Service, Azure Monitor). |
| `log_analytics_workspace_id` | `string` | `null` | Destination for diagnostics. |
| `tags` | `map(string)` | `{}` | Tags for every resource. |

## Outputs

| Name | Description |
|------|-------------|
| `resource_group_name` | Hub resource group. |
| `virtual_network_id` | Hub VNet ID. Spokes peer to this. |
| `virtual_network_name` | Hub VNet name. |
| `subnet_ids` | Subnet name to ID. |
| `firewall_private_ip` | Next hop and DNS server for spokes, or `null`. |
| `firewall_policy_id` | Firewall policy ID for rule collection groups, or `null`. |
| `bastion_host_id` | Bastion ID, or `null`. |
| `private_dns_zone_ids` | Zone name to zone ID, for private endpoint DNS zone groups. |

## Tests

`terraform test` runs plan-only tests against a mocked provider (no credentials): defaults, firewall toggle and subnet sizing validation.
