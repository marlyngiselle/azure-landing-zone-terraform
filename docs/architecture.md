# Architecture

This landing zone follows the Cloud Adoption Framework design areas, with a deliberately small surface: what most organisations need in their first year on Azure, built so it can grow without a rewrite.

## Management group and subscription layout

```mermaid
flowchart TD
    root["Tenant root group"] --> top["contoso"]
    top --> platform["contoso-platform"]
    top --> lz["contoso-landingzones<br/><i>policy-baseline assigned here</i>"]
    top --> sandbox["contoso-sandbox"]
    top --> decom["contoso-decommissioned"]

    platform --> conn["sub: connectivity<br/>hub-network"]
    platform --> mgmt["sub: management<br/>management"]

    lz --> corp["contoso-landingzones-corp<br/><i>private, peered to hub</i>"]
    lz --> online["contoso-landingzones-online<br/><i>internet-facing PaaS</i>"]

    corp --> pay["sub: payments-prd<br/>subscription-vending"]
    online --> ana["sub: analytics-dev<br/>subscription-vending"]
```

The management group hierarchy itself is a one-off, tenant-level bootstrap and is not part of these modules. The modules take management group IDs as inputs so they work with any hierarchy.

## Network topology

```mermaid
flowchart LR
    internet((Internet))

    subgraph conn["Connectivity subscription"]
        subgraph hub["vnet-hub-prd-weu 10.100.0.0/22"]
            afw["Azure Firewall<br/>Premium, DNS proxy<br/>threat intel: Deny"]
            bas["Azure Bastion"]
            gw["GatewaySubnet<br/>(VPN / ExpressRoute)"]
        end
        dns[("Private DNS zones<br/>privatelink.*")]
    end

    subgraph lz1["payments-prd subscription"]
        subgraph spoke1["vnet-payments-prd-weu 10.110.0.0/22"]
            app1["snet-app<br/>NSG + UDR"]
            data1["snet-data<br/>private endpoints"]
        end
    end

    subgraph lz2["another landing zone"]
        spoke2["vnet-...<br/>NSG + UDR"]
    end

    hub <-- "peering" --> spoke1
    hub <-- "peering" --> spoke2
    dns -. "linked to hub" .- hub
    app1 -- "0.0.0.0/0 via firewall" --> afw
    afw --> internet
    gw --- onprem[(On-premises)]
```

Traffic rules that fall out of this design:

| Flow | Path |
|------|------|
| Spoke to internet | UDR `0.0.0.0/0` to the firewall, SNAT on the firewall public IP. Default outbound access is disabled on every subnet, so there is no other way out. |
| Spoke to spoke | Through the firewall (no transitive peering), so east-west traffic is inspected and logged. |
| Spoke to PaaS | Private endpoint in the spoke, name resolved by the firewall DNS proxy against the private DNS zones linked to the hub. |
| Admin access to VMs | Bastion in the hub. Public IPs on NICs are denied by policy. |
| On-premises | Gateway in the hub, `use_remote_gateways` opt in per spoke. |

## Module composition

```mermaid
flowchart TB
    subgraph platform["Platform pipeline (one state)"]
        mgmt["management"]
        hubm["hub-network"]
        pol["policy-baseline"]
    end

    subgraph vending["Vending pipeline (one state per request)"]
        req[/"requests/*.yaml"/] -->|yamldecode| sv["subscription-vending"]
        sv --> spoke["spoke-network"]
    end

    diag["management/modules/diagnostic-settings"]

    mgmt -->|workspace id| hubm
    mgmt -->|workspace id, action group| sv
    hubm -->|vnet id, firewall ip| sv
    hubm --> diag
    spoke --> diag
```

Two lifecycles, two pipelines: the platform changes rarely and is owned by the platform team; landing zones change often and are requested by application teams. Splitting state along that line keeps the blast radius of a landing zone change to that landing zone.

## What is intentionally out of scope

- Management group hierarchy bootstrap and tenant-level settings.
- Subscription creation (billing-agreement specific, see [ADR 0004](adr/0004-subscription-vending-from-requests.md)).
- Identity: Entra ID groups and workload identities are created upstream; requests reference them by object ID.
- Firewall rule collection groups: owned by the teams that own the flows, attached to the exported `firewall_policy_id`.
