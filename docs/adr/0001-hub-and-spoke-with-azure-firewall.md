# ADR 0001: Hub and spoke with Azure Firewall rather than Virtual WAN

- Status: Accepted
- Date: 2026-10-26

## Context

Workloads need private connectivity to each other, to on-premises and to PaaS services, with every flow inspected and logged. Azure offers two reference topologies: a customer-managed hub and spoke, and Virtual WAN with secured virtual hubs.

The expected footprint is one or two regions and a few dozen spokes in the first years, with a single platform team operating the network.

## Decision

Use a customer-managed hub VNet per region with Azure Firewall (Standard or Premium) and an Azure Firewall Policy. Spokes peer to the hub and send `0.0.0.0/0` to the firewall through a route table with BGP propagation disabled.

Firewall and Bastion are toggles, so the same module serves a cheap sandbox hub and a production hub.

## Consequences

- Full control over routing, DNS and subnet layout in the hub, with plain VNet resources that every engineer already understands.
- The firewall private IP becomes a hard dependency of every spoke (route table and DNS). It is exported by the hub module and passed explicitly, never looked up.
- Spoke-to-spoke traffic is inspected by default because peering is not transitive.
- Beyond roughly three regions, or with many branch sites, Virtual WAN becomes the better trade-off. The spoke module only depends on a VNet ID and a next-hop IP, so moving spokes to a secured virtual hub later does not require rewriting it.
- Basic firewall SKU is not offered: it has no DNS proxy and needs a separate management subnet, which would break the "firewall is the DNS server" model.
