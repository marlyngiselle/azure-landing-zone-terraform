# ADR 0002: Policy as code with custom definitions and parameterised effects

- Status: Accepted
- Date: 2026-10-26

## Context

Guardrails must apply to everything in a landing zone, including resources created outside Terraform. They also have to be introduced into subscriptions that already contain non-compliant resources without breaking running deployments.

Large policy libraries exist (the Azure Landing Zones reference ships hundreds of assignments). Adopted wholesale, they are hard to reason about and teams end up with exemptions nobody can explain.

## Decision

- Start with four controls that have the highest value per unit of friction: allowed locations, required tags, no public IP on NICs, diagnostics to Log Analytics.
- Store each definition as a plain Azure Policy JSON file in `modules/policy-baseline/policies/`, loaded with `jsondecode(file())`. The file is the source of truth and can be tested outside Terraform.
- Group them in one initiative and expose every effect as an initiative parameter.
- Assign at the landing zones management group so new subscriptions inherit the baseline the moment they are placed.
- Roll out in brownfield scopes with `Audit` (or `enforce = false`), remediate, then switch to `Deny`.
- Avoid `DeployIfNotExists` and `Modify` in the baseline. Diagnostics are configured by the modules themselves; policy only audits.

## Consequences

- Moving a control from audit to deny is a one-line, reviewable change on the assignment.
- The required tags are the same five tags the vending module sets, so a vended landing zone is compliant on day one by construction.
- No managed identity or role assignment is needed for the assignment, which keeps the policy layer free of standing privileged access.
- Additional controls (for example, denying public network access on PaaS) are added one file at a time, with their own non-compliance message.
