# The shortest service name (3 characters), which some provider identifiers derive from: service account IDs need 6.
# tests/run.sh renders it and runs this file with mock providers.

mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/shared/serviceAccounts/ci-orders@shared.iam.gserviceaccount.com"
      email = "ci-orders@shared.iam.gserviceaccount.com"
    }
  }
}

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
    defaults = { html_url = "https://github.com/Laratechs/aaa" }
  }
}

run "apply" {
  assert {
    condition     = output.service.image == "ghcr.io/laratechs/aaa" && output.service.repository_url == "https://github.com/Laratechs/aaa"
    error_message = "service status: ${jsonencode(output.service)}"
  }
  assert {
    # CI's settings are committed after its variables, so the CLI can follow
    # the run that uses them.
    condition     = output.service.ci_commit != ""
    error_message = "ci_commit: ${output.service.ci_commit}"
  }
  assert {
    condition     = length(local.children_cloud) == 2
    error_message = "children: ${jsonencode(local.children_cloud)}"
  }
  assert {
    condition     = output.cloud_aws.provider == "aws" && output.cloud_aws.id != ""
    error_message = "aws status: ${jsonencode(output.cloud_aws)}"
  }
  assert {
    condition     = output.cloud_gcp.provider == "gcp" && output.cloud_gcp.id != ""
    error_message = "gcp status: ${jsonencode(output.cloud_gcp)}"
  }
  assert {
    # CI gets what it needs to push to the service's own image repository
    # and deploy its Cloud Run service.
    condition = alltrue([
      local.cloud_gcp_exports.ANVIL_GCP_IMAGE == "us-central1-docker.pkg.dev/shared/aaa/aaa",
      local.cloud_gcp_exports.ANVIL_GCP_SERVICE == "aaa",
      local.cloud_gcp_exports.ANVIL_GCP_SERVICE_ACCOUNT != "",
      startswith(local.cloud_gcp_exports.ANVIL_GCP_WORKLOAD_IDENTITY_PROVIDER, "projects/123/"),
    ])
    error_message = "gcp exports: ${jsonencode(local.cloud_gcp_exports)}"
  }
  assert {
    condition     = output.cloud_gcp.public == true
    error_message = "gcp public: ${jsonencode(output.cloud_gcp)}"
  }
}
