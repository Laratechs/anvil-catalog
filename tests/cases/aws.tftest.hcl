# Service orders with the aws cloud.
# tests/run.sh renders it and runs this file with mock providers.

mock_provider "aws" {
  mock_data "aws_ssoadmin_instances" {
    defaults = { arns = ["arn:aws:sso:::instance/ssoins-1234567890abcdef"], identity_store_ids = ["d-1234567890"] }
  }
  mock_data "aws_identitystore_group" {
    defaults = { group_id = "12345678-1234-1234-1234-123456789012" }
  }
  mock_resource "aws_organizations_account" {
    defaults = { id = "123456789012" }
  }
}

mock_provider "github" {
  mock_data "github_repository_file" {
    defaults = { content = "# kept in sync\n.golangci.yml\n" }
  }
  mock_resource "github_repository" {
    defaults = { html_url = "https://github.com/Laratechs/orders" }
  }
}

run "apply" {
  assert {
    condition     = output.service.image == "ghcr.io/laratechs/orders" && output.service.repository_url == "https://github.com/Laratechs/orders"
    error_message = "service status: ${jsonencode(output.service)}"
  }
  assert {
    # CI's settings are committed after its variables, so the CLI can follow
    # the run that uses them.
    condition     = output.service.ci_commit != ""
    error_message = "ci_commit: ${output.service.ci_commit}"
  }
  assert {
    condition     = length(local.children_cloud) == 1
    error_message = "children: ${jsonencode(local.children_cloud)}"
  }
  assert {
    condition     = output.cloud_aws.provider == "aws" && output.cloud_aws.id != ""
    error_message = "aws status: ${jsonencode(output.cloud_aws)}"
  }
}
