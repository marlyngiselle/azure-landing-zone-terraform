# Full example

The production shape: platform plus one vended landing zone per run.

- `management`: workspace, platform action group and a monthly platform budget.
- `hub-network`: Azure Firewall Premium, Bastion, gateway subnet and the default private DNS zones.
- `policy-baseline`: assigned at the landing zones management group, in `Deny` mode.
- `subscription-vending`: applies the request in `var.request_file`.

## Applying a request

Each request is its own state. In a pipeline:

```bash
for request in requests/*.yaml; do
  key="lz/$(basename "$request" .yaml).tfstate"
  terraform init -reconfigure -backend-config="key=${key}"
  terraform apply -var "request_file=${request}"
done
```

In practice the platform layer (management, hub, policy) is split into its own root module and the vending root reads its outputs from remote state. They are kept together here so the example is self-contained.

## Requests

| File | What it shows |
|------|---------------|
| [`requests/payments-prd.yaml`](requests/payments-prd.yaml) | Production, confidential data, spoke with private endpoint subnet, reader and pipeline roles, budget with three thresholds. |
| [`requests/analytics-dev.yaml`](requests/analytics-dev.yaml) | Development, PaaS only: no network block, so no spoke and no address space consumed. |
