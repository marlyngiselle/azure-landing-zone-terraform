# Architecture decision records

Short records of the decisions that shape this landing zone. Each one states the context, the decision and the consequences, including the ones that hurt.

| ADR | Decision | Status |
|-----|----------|--------|
| [0001](0001-hub-and-spoke-with-azure-firewall.md) | Hub and spoke with Azure Firewall rather than Virtual WAN | Accepted |
| [0002](0002-policy-as-code-with-custom-definitions.md) | Policy as code: JSON definitions, effects as parameters, audit before deny | Accepted |
| [0003](0003-private-by-default-networking.md) | Private by default: forced egress, no public IPs on NICs, central private DNS | Accepted |
| [0004](0004-subscription-vending-from-requests.md) | Subscription vending from YAML requests, one state per landing zone | Accepted |
