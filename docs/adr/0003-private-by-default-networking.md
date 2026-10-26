# ADR 0003: Private by default networking

- Status: Accepted
- Date: 2026-10-26

## Context

The most common way an Azure environment leaks data is not a sophisticated attack but a convenience: a VM with a public IP for "quick access", a storage account left on a public endpoint, a subnet with implicit outbound access nobody inspects.

## Decision

- Every spoke subnet sends `0.0.0.0/0` to the hub firewall, and `default_outbound_access_enabled` is `false` on every subnet, hub and spoke. Egress has exactly one path.
- Public IPs on network interfaces are denied by policy. Administrative access goes through Bastion; published workloads go through an ingress service in the hub.
- PaaS services are consumed through private endpoints. The private DNS zones live once, in the hub, linked to the hub VNet only.
- Spokes use the firewall DNS proxy as their DNS server, so private endpoint names resolve the same way from every spoke and from on-premises (through a forwarder to the firewall).
- Every subnet has an NSG, even if it only carries the platform defaults, so rules can be added without a structural change.

## Consequences

- One place to resolve private endpoint DNS, no zone duplication per spoke, no split-brain resolution.
- Egress is visible in firewall logs, which makes data exfiltration reviews and FinOps attribution of bandwidth possible.
- Teams cannot open a VM to the internet "temporarily". When they genuinely need ingress, it is a platform conversation, which is the point.
- Landing zones that only use public PaaS endpoints in development can omit the network block entirely (see the `analytics-dev` request), rather than getting a spoke they do not use.
