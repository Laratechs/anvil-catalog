# An AWS account for one Anvil service in AWS Organizations, with the owning
# team's IAM Identity Center group assigned permission sets on it.

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
    anvil-team    = var.team
  }

  lifecycle {
    prevent_destroy = true
    # AWS does not return role_name after creation.
    ignore_changes = [role_name]
  }
}

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

data "aws_identitystore_group" "team" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = var.group_display_name
    }
  }
}

resource "aws_ssoadmin_account_assignment" "team" {
  for_each = toset(var.permission_set_arns)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = each.value
  principal_id       = data.aws_identitystore_group.team.group_id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.this.id
  target_type        = "AWS_ACCOUNT"
}
