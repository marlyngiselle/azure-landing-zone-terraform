# spoke-network

A workload spoke: VNet, subnets with one NSG each, a route table that forces egress through the hub firewall, and peering in both directions.

## Providers

The module needs two azurerm providers, because the hub side of the peering lives in the connectivity subscription:

| Provider | Targets |
|----------|---------|
| `azurerm` | The spoke subscription. |
| `azurerm.hub` | The subscription that owns the hub VNet. |

In a single-subscription setup pass the same provider twice.

## Usage

```hcl
module "spoke" {
  source = "../../modules/spoke-network"

  providers = {
    azurerm     = azurerm.landing_zone
    azurerm.hub = azurerm.connectivity
  }

  name                = "payments-prd-weu"
  location            = "westeurope"
  resource_group_name = "rg-payments-prd-weu-network"
  address_space       = ["10.110.0.0/22"]

  hub = {
    virtual_network_id  = module.hub.virtual_network_id
    firewall_private_ip = module.hub.firewall_private_ip
  }

  subnets = {
    app = {
      address_prefixes = ["10.110.0.0/24"]
      security_rules = [{
        name                    = "allow-https-from-hub"
        priority                = 200
        direction               = "Inbound"
        access                  = "Allow"
        protocol                = "Tcp"
        source_address_prefix   = "10.100.0.0/22"
        destination_port_ranges = ["443"]
      }]
    }
    data = {
      address_prefixes  = ["10.110.1.0/26"]
      private_endpoints = true
    }
  }
}
```

## Behaviour

- Every subnet gets its own NSG named `nsg-<name>-<key>`. Rules are data, keyed by `<subnet>.<rule>` so that reordering never recreates rules.
- When the hub has a firewall, a route table sends `0.0.0.0/0` to it with BGP propagation disabled, and the VNet uses the firewall DNS proxy. Opt a subnet out with `route_to_firewall = false`.
- Default outbound access is disabled on every subnet.
- `private_endpoints = true` enables network policies for private endpoints, so NSGs and UDRs apply to them.
- Gateway transit is opt in through `hub.use_remote_gateways`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | n/a | Name token `<workload>-<env>-<region>`, validated. |
| `location` | `string` | n/a | Azure region. |
| `resource_group_name` | `string` | n/a | Existing resource group for the spoke. |
| `address_space` | `list(string)` | n/a | Spoke address space, validated as CIDRs. |
| `subnets` | `map(object)` | `{}` | `address_prefixes`, `service_endpoints`, `private_endpoints`, `route_to_firewall` (`true`), `delegation_service`, `delegation_actions`, `security_rules` (priority 100 to 4000, validated). |
| `hub` | `object` | n/a | `virtual_network_id` (validated), `firewall_private_ip` (optional), `use_remote_gateways` (`false`). |
| `dns_servers` | `list(string)` | `null` | Override DNS. Defaults to the firewall when present. |
| `log_analytics_workspace_id` | `string` | `null` | Destination for VNet and NSG diagnostics. |
| `tags` | `map(string)` | `{}` | Tags for every resource. |

## Outputs

| Name | Description |
|------|-------------|
| `virtual_network_id` | Spoke VNet ID. |
| `virtual_network_name` | Spoke VNet name. |
| `subnet_ids` | Subnet key to subnet ID. |
| `network_security_group_ids` | Subnet key to NSG ID. |
| `route_table_id` | Route table ID, or `null` without a firewall. |

## Tests

`terraform test` covers forced egress, NSG coverage, two-sided peering, the no-firewall path and rule validation, with mocked providers.
