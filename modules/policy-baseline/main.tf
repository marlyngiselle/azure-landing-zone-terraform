locals {
  is_management_group = var.scope.type == "management_group"
  definitions_path    = "${path.module}/policies"

  definitions = {
    for f in fileset(local.definitions_path, "*.json") :
    trimsuffix(f, ".json") => jsondecode(file("${local.definitions_path}/${f}"))
  }

  set_definition_id = local.is_management_group ? azurerm_management_group_policy_set_definition.this[0].id : azurerm_policy_set_definition.this[0].id

  # Initiative-level parameters, surfaced so assignments can tune effects without editing definitions.
  set_parameters = {
    listOfAllowedLocations  = { type = "Array", metadata = { displayName = "Allowed locations" } }
    diagnosticResourceTypes = { type = "Array", metadata = { displayName = "Resource types requiring diagnostics" } }
    allowedLocationsEffect  = { type = "String", defaultValue = "Deny", allowedValues = ["Audit", "Deny", "Disabled"] }
    requiredTagsEffect      = { type = "String", defaultValue = "Deny", allowedValues = ["Audit", "Deny", "Disabled"] }
    publicIpOnNicEffect     = { type = "String", defaultValue = "Deny", allowedValues = ["Audit", "Deny", "Disabled"] }
    diagnosticsEffect       = { type = "String", defaultValue = "AuditIfNotExists", allowedValues = ["AuditIfNotExists", "Disabled"] }
  }

  references = concat(
    [
      {
        reference_id = "allowed-locations"
        definition   = "allowed-locations"
        parameters = {
          listOfAllowedLocations = { value = "[parameters('listOfAllowedLocations')]" }
          effect                 = { value = "[parameters('allowedLocationsEffect')]" }
        }
      },
      {
        reference_id = "deny-public-ip-on-nic"
        definition   = "deny-public-ip-on-nic"
        parameters = {
          effect = { value = "[parameters('publicIpOnNicEffect')]" }
        }
      },
      {
        reference_id = "require-diagnostic-settings"
        definition   = "require-diagnostic-settings"
        parameters = {
          resourceTypes = { value = "[parameters('diagnosticResourceTypes')]" }
          effect        = { value = "[parameters('diagnosticsEffect')]" }
        }
      },
    ],
    [
      for tag in sort(tolist(var.required_tags)) : {
        reference_id = "require-tag-${tag}"
        definition   = "require-tag"
        parameters = {
          tagName = { value = tag }
          effect  = { value = "[parameters('requiredTagsEffect')]" }
        }
      }
    ],
  )

  assignment_parameters = jsonencode({
    listOfAllowedLocations  = { value = var.allowed_locations }
    diagnosticResourceTypes = { value = var.diagnostic_resource_types }
    allowedLocationsEffect  = { value = var.effects.allowed_locations }
    requiredTagsEffect      = { value = var.effects.required_tags }
    publicIpOnNicEffect     = { value = var.effects.deny_public_ip_nic }
    diagnosticsEffect       = { value = var.effects.diagnostic_settings }
  })

  non_compliance_messages = {
    "allowed-locations"           = "Resources must be deployed in an approved region."
    "deny-public-ip-on-nic"       = "Public IPs on network interfaces are not allowed. Publish workloads through the hub."
    "require-diagnostic-settings" = "Send diagnostics to the platform Log Analytics workspace."
  }
}

# ---------------------------------------------------------------------------
# Custom definitions (policy as code: JSON files under ./policies)
# ---------------------------------------------------------------------------

resource "azurerm_policy_definition" "this" {
  for_each = local.definitions

  name                = "${var.name_prefix}-${each.key}"
  display_name        = each.value.displayName
  description         = each.value.description
  mode                = each.value.mode
  policy_type         = "Custom"
  management_group_id = local.is_management_group ? var.scope.id : null
  metadata            = jsonencode(each.value.metadata)
  parameters          = jsonencode(each.value.parameters)
  policy_rule         = jsonencode(each.value.policyRule)
}

# ---------------------------------------------------------------------------
# Initiative
# ---------------------------------------------------------------------------

resource "azurerm_management_group_policy_set_definition" "this" {
  count = local.is_management_group ? 1 : 0

  name                = "${var.name_prefix}-baseline"
  display_name        = "Landing zone security baseline"
  description         = "Region restriction, mandatory tags, no public IPs on NICs and diagnostics to Log Analytics."
  policy_type         = "Custom"
  management_group_id = var.scope.id
  metadata            = jsonencode({ category = "Landing Zone", version = "1.0.0" })
  parameters          = jsonencode(local.set_parameters)

  dynamic "policy_definition_reference" {
    for_each = local.references

    content {
      reference_id         = policy_definition_reference.value.reference_id
      policy_definition_id = azurerm_policy_definition.this[policy_definition_reference.value.definition].id
      parameter_values     = jsonencode(policy_definition_reference.value.parameters)
    }
  }
}

resource "azurerm_policy_set_definition" "this" {
  count = local.is_management_group ? 0 : 1

  name         = "${var.name_prefix}-baseline"
  display_name = "Landing zone security baseline"
  description  = "Region restriction, mandatory tags, no public IPs on NICs and diagnostics to Log Analytics."
  policy_type  = "Custom"
  metadata     = jsonencode({ category = "Landing Zone", version = "1.0.0" })
  parameters   = jsonencode(local.set_parameters)

  dynamic "policy_definition_reference" {
    for_each = local.references

    content {
      reference_id         = policy_definition_reference.value.reference_id
      policy_definition_id = azurerm_policy_definition.this[policy_definition_reference.value.definition].id
      parameter_values     = jsonencode(policy_definition_reference.value.parameters)
    }
  }
}

# ---------------------------------------------------------------------------
# Assignment
# ---------------------------------------------------------------------------

resource "azurerm_management_group_policy_assignment" "this" {
  count = local.is_management_group ? 1 : 0

  name                 = var.assignment.name
  display_name         = var.assignment.display_name
  management_group_id  = var.scope.id
  policy_definition_id = local.set_definition_id
  enforce              = var.assignment.enforce
  not_scopes           = var.assignment.not_scopes
  location             = var.assignment.location
  parameters           = local.assignment_parameters

  dynamic "non_compliance_message" {
    for_each = local.non_compliance_messages

    content {
      policy_definition_reference_id = non_compliance_message.key
      content                        = non_compliance_message.value
    }
  }
}

resource "azurerm_subscription_policy_assignment" "this" {
  count = local.is_management_group ? 0 : 1

  name                 = var.assignment.name
  display_name         = var.assignment.display_name
  subscription_id      = var.scope.id
  policy_definition_id = local.set_definition_id
  enforce              = var.assignment.enforce
  not_scopes           = var.assignment.not_scopes
  location             = var.assignment.location
  parameters           = local.assignment_parameters

  dynamic "non_compliance_message" {
    for_each = local.non_compliance_messages

    content {
      policy_definition_reference_id = non_compliance_message.key
      content                        = non_compliance_message.value
    }
  }
}
