# An AWS account for one Anvil service in AWS Organizations.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_organizations_account" "this" {
  name                       = var.service
  email                      = replace(var.email_template, "{service}", var.service)
  parent_id                  = var.parent_id != "" ? var.parent_id : null
  role_name                  = "OrganizationAccountAccessRole"
  iam_user_access_to_billing = "DENY"
  close_on_deletion          = false

  tags = {
    managed-by    = "anvil"
    anvil-service = var.service
  }

  lifecycle {
    prevent_destroy = true
    # AWS does not return role_name after creation.
    ignore_changes = [role_name]
  }
}
