# Account Verification Mixin
#
# Purpose:
# Verifies that Terraform is executing in the correct target AWS account by comparing the current
# AWS account ID against the expected account ID based on the component's context (tenant-stage).
#
# When to use:
# - When account_map_enabled is false and Atmos Auth has assumed the target role before Terraform runs
# - Provides safety check to ensure the assumed identity is operating in the intended account
#
# How it works:
# 1. Retrieves the current AWS account ID from the active AWS credentials
# 2. Constructs the expected account name from context variables (format: "tenant-stage")
# 3. Looks up the expected account ID from the account_map variable
# 4. Validates that current account ID matches expected account ID
# 5. Fails with a clear error message if accounts don't match
#
# Note: Validation only occurs when account_verification_enabled is true (default),
# account_map.full_account_map is populated and the expected account name can be constructed from
# tenant and stage variables.
#
# Set account_verification_expected_account_name when a stack's account is not named "tenant-stage"
# (e.g. one stage spanning several accounts). The given name replaces "tenant-stage" as the
# account_map.full_account_map key, and verification becomes fail-closed: a name missing from the map
# fails the check instead of skipping it.

variable "account_verification_enabled" {
  type        = bool
  description = <<-DOC
  Enable account verification. When true (default), verify that Terraform is executing in the expected AWS
  account by comparing the current account ID against the expected account from account_map.full_account_map.
  DOC
  default     = true
  nullable    = false
}

variable "account_verification_expected_account_name" {
  type        = string
  description = <<-DOC
  Account name (an account_map.full_account_map key) to expect instead of "tenant-stage".
  When set, verification always runs and a name missing from account_map.full_account_map fails the check.
  DOC
  default     = null

  validation {
    condition     = var.account_verification_expected_account_name == null || try(length(var.account_verification_expected_account_name) > 0, false)
    error_message = "account_verification_expected_account_name must be null or a non-empty string."
  }
}

# Get current AWS account ID for verification
data "aws_caller_identity" "account_verification" {}

locals {
  # True when the expected account name is given explicitly rather than derived from tenant and stage.
  expected_account_name_set = var.account_verification_expected_account_name != null

  # Expected account name: account_verification_expected_account_name when set, otherwise "tenant-stage".
  # Only construct "tenant-stage" if both tenant and stage are non-null and non-empty strings.
  expected_account_name = local.expected_account_name_set ? var.account_verification_expected_account_name : (
    (
      try(var.tenant, null) != null &&
      try(var.stage, null) != null &&
      try(var.tenant, "") != "" &&
      try(var.stage, "") != ""
    ) ? "${var.tenant}-${var.stage}" : null
  )

  # Look up the expected account ID from account_map using the expected account name.
  # Returns null if account name cannot be constructed or if the name is not found in the map.
  expected_account_id = try(
    local.expected_account_name != null ? var.account_map.full_account_map[local.expected_account_name] : null,
    null
  )

  # Current AWS account ID from the active credentials (via Atmos Auth or AWS provider)
  current_account_id = data.aws_caller_identity.account_verification.account_id

  # Determine if validation should be performed. It requires account_verification_enabled, and then either:
  # - account_verification_expected_account_name is set (fail-closed: always validate), or
  # - all three of:
  #   1. account_map.full_account_map is provided and not empty
  #   2. Expected account name can be constructed from tenant and stage
  #   3. Expected account ID exists in the account_map for the constructed account name
  should_validate = var.account_verification_enabled && (
    local.expected_account_name_set || (
      length(var.account_map.full_account_map) > 0 &&
      local.expected_account_name != null &&
      local.expected_account_id != null
    )
  )

  # Error message for account mismatch.
  # Must always return a string (never null) for use in precondition error_message.
  validation_error = !local.should_validate || local.current_account_id == local.expected_account_id ? "Account verification check passed" : (
    local.expected_account_name_set ? (
      local.expected_account_id == null ? (
        "Account verification failed: Expected account '${local.expected_account_name}' (account_verification_expected_account_name) is not in account_map.full_account_map; current account ID is ${local.current_account_id}"
        ) : (
        "Account verification failed: Expected account ID ${local.expected_account_id} for account '${local.expected_account_name}' (account_verification_expected_account_name), but current account ID is ${local.current_account_id}"
      )
      ) : (
      "Account verification failed: Expected account ID ${local.expected_account_id} for account '${local.expected_account_name}' (tenant: ${var.tenant}, stage: ${var.stage}), but current account ID is ${local.current_account_id}"
    )
  )
}

# Perform account verification using terraform_data resource with lifecycle precondition.
# This resource is only created when validation should be performed (should_validate = true).
#
# The precondition ensures that the current account ID matches the expected account ID,
# failing the Terraform run with a descriptive error if there's a mismatch.
#
# Note: terraform_data is available in Terraform 1.4+. For earlier versions, this still works
# but validation happens at plan time rather than during the lifecycle check.
resource "terraform_data" "account_verification" {
  count = local.should_validate ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.current_account_id == local.expected_account_id
      error_message = local.validation_error
    }
  }
}
