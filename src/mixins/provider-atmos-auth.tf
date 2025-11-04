# Account Verification for Atmos Auth Identity Selection
#
# Purpose:
# We use Atmos auth to select an identity (AWS IAM role/user) to run Terraform. This file ensures
# that the selected identity is operating in the correct AWS account that we intend to target.
#
# How it works:
# 1. Gets the current AWS account ID from the identity selected via Atmos auth
# 2. Compares it against the expected account ID derived from the context (tenant-stage)
# 3. Uses the account_map variable to look up the expected account ID based on the tenant-stage
#    naming convention (format: "tenant-stage")
# 4. If verification is enabled and the accounts don't match, Terraform will fail with a clear error
#
# This verification process ensures that when using Atmos auth to select an identity, we're
# targeting the correct account as determined by the component's context variables.

# Get current AWS account ID for verification
data "aws_caller_identity" "account_verification" {}

# Optional account map for account verification
# If provided, will verify that the current AWS account matches the expected account
# based on tenant-stage naming convention (format: "tenant-stage")
# Note: If this variable is already defined in variables.tf, Terraform will use that definition
variable "account_map" {
  type = object({
    full_account_map           = map(string)
    audit_account_account_name = optional(string, "")
    root_account_account_name  = optional(string, "")
  })
  description = "Map of account names (tenant-stage format) to account IDs. Used to verify we're targeting the correct AWS account. Optional attributes support component-specific functionality (e.g., audit_account_account_name for cloudtrail, root_account_account_name for aws-sso)."
  default = {
    full_account_map           = {}
    audit_account_account_name = ""
    root_account_account_name  = ""
  }
}

# Compute expected account name from tenant and stage
locals {
  # Construct expected account name in format "tenant-stage"
  # Only construct if both tenant and stage are non-null and non-empty
  expected_account_name = (
    try(var.tenant, null) != null &&
    try(var.stage, null) != null &&
    try(var.tenant, "") != "" &&
    try(var.stage, "") != ""
  ) ? "${var.tenant}-${var.stage}" : null

  # Get expected account ID from account_map if account_map is provided and account name can be constructed
  expected_account_id = try(
    local.expected_account_name != null ? var.account_map.full_account_map[local.expected_account_name] : null,
    null
  )

  # Current account ID
  current_account_id = data.aws_caller_identity.account_verification.account_id

  # Only validate if:
  # 1. account_map is provided (not empty)
  # 2. Expected account name can be constructed from tenant-stage
  # 3. Expected account ID exists in the account_map
  should_validate = (
    length(var.account_map.full_account_map) > 0 &&
    local.expected_account_name != null &&
    local.expected_account_id != null
  )

  # Validation error message
  # Must always be a string (never null) for use in precondition error_message
  validation_error = local.should_validate && local.current_account_id != local.expected_account_id ? (
    "Account verification failed: Expected account ID ${local.expected_account_id} for account '${local.expected_account_name}' (tenant: ${var.tenant}, stage: ${var.stage}), but current account ID is ${local.current_account_id}"
  ) : "Account verification check passed"
}

# Validate account matches expected account when account_map is provided
# Using terraform_data (available in Terraform 1.4+) for validation
# For Terraform < 1.4, this will still work but validation happens at plan time
resource "terraform_data" "account_verification" {
  count = local.should_validate ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.current_account_id == local.expected_account_id
      error_message = local.validation_error
    }
  }
}

provider "aws" {
  region = var.region
}
