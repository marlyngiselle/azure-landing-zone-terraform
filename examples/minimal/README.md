# Minimal example

A complete landing zone in a single sandbox subscription, sized to cost close to nothing:

- `management`: Log Analytics workspace with 30-day retention.
- `hub-network`: hub VNet with a shared subnet and two private DNS zones. No firewall, no Bastion.
- `spoke-network`: one spoke with an application subnet and a private endpoint subnet, peered to the hub.
- `policy-baseline`: assigned at subscription scope in `DoNotEnforce` mode, so it reports without blocking.

```bash
cp terraform.tfvars.example terraform.tfvars   # set your sandbox subscription ID
terraform init
terraform plan
```
