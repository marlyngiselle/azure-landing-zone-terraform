# ADR 0004: Subscription vending from YAML requests, one state per landing zone

- Status: Accepted
- Date: 2026-10-26

## Context

Application teams need new subscriptions regularly. Without a vending process, each one is a ticket, a set of manual steps and a slightly different result. With a single Terraform state for all landing zones, every change plans against every subscription, and one broken request blocks everyone.

## Decision

- A landing zone is described by a YAML request in `requests/`, reviewed and approved through a pull request. The request states what the team needs (name, environment, network size, access, budget); the module decides how it is built.
- The `subscription-vending` module validates the request at plan time: environment values, GUID formats, owner email, role scopes, and a hard refusal of privileged roles.
- Each request is applied as its own Terraform state. The pipeline iterates over request files and runs the same root module with `-var request_file=...` and a backend key derived from the file name. The landing zone provider is configured from the request's `subscription_id`.
- Cross-request invariants (unique name and environment, unique subscription) are enforced with `check` blocks that read every request file on each run.
- The module lands an existing subscription rather than creating it. Creation through `azurerm_subscription` aliases requires a billing scope and approvals that differ between EA, MCA and CSP, and is better handled by a separate, tightly permissioned step.

## Consequences

- Self-service with guardrails: teams open a pull request, the platform team reviews a twenty-line YAML file rather than Terraform code.
- Blast radius of a change is one landing zone. Plans are fast and failures are isolated.
- The vending identity needs rights on the target subscription and on the hub (for the hub-side peering), but never Owner on the tenant.
- Changing the module affects every landing zone, so module releases are versioned and rolled out request by request.
