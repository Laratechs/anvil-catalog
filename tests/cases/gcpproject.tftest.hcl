# Service orders with a GCP project of its own (the self-managed deployment).
# tests/run.sh renders it and runs this file with mock providers.

mock_provider "google" {
  mock_resource "google_project" {
    defaults = { number = "123456789012" }
  }
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/lt-orders/serviceAccounts/ci-orders@lt-orders.iam.gserviceaccount.com"
      email = "ci-orders@lt-orders.iam.gserviceaccount.com"
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
    condition     = output.service.repository_url == "https://github.com/Laratechs/orders"
    error_message = "service status: ${jsonencode(output.service)}"
  }
  assert {
    condition     = length(local.children_cloud) == 1 && local.children_cloud[0].name == "gcpproject" && local.children_cloud[0].type == "self-managed"
    error_message = "children: ${jsonencode(local.children_cloud)}"
  }
  assert {
    # CI can authenticate and publish the image. Nothing names a service
    # to deploy to, so the template's deploy job stays off.
    condition = local.children_cloud[0].exports == {
      ANVIL_GCP_PROJECT                    = "lt-orders"
      ANVIL_GCP_REGION                     = "us-central1"
      ANVIL_GCP_IMAGE                      = "us-central1-docker.pkg.dev/lt-orders/orders/orders"
      ANVIL_GCP_SERVICE_ACCOUNT            = "ci-orders@lt-orders.iam.gserviceaccount.com"
      ANVIL_GCP_WORKLOAD_IDENTITY_PROVIDER = "projects/123/locations/global/workloadIdentityPools/github/providers/github"
    }
    error_message = "exports: ${jsonencode(local.children_cloud[0].exports)}"
  }
  assert {
    condition = (
      output.cloud_gcpproject.kind == "gcp_project" &&
      output.cloud_gcpproject.id == "lt-orders" &&
      output.cloud_gcpproject.console_url == "https://console.cloud.google.com/home/dashboard?project=lt-orders"
    )
    error_message = "status: ${jsonencode(output.cloud_gcpproject)}"
  }
}
