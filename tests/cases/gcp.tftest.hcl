# Service orders with the gcp cloud.
# tests/run.sh renders it and runs this file with mock providers.

mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/shared/serviceAccounts/ci-orders@shared.iam.gserviceaccount.com"
      email = "ci-orders@shared.iam.gserviceaccount.com"
    }
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
    condition     = output.cloud_gcp.provider == "gcp" && output.cloud_gcp.id != ""
    error_message = "gcp status: ${jsonencode(output.cloud_gcp)}"
  }
  assert {
    # CI gets what it needs to push to the service's own image repository
    # and deploy its Cloud Run service.
    condition = alltrue([
      local.cloud_gcp_exports.ANVIL_GCP_IMAGE == "us-central1-docker.pkg.dev/shared/orders/orders",
      local.cloud_gcp_exports.ANVIL_GCP_SERVICE == "orders",
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
