# Service orders with a GCP project of its own (the self-managed deployment).
# tests/run.sh renders it and runs this file with mock providers.

mock_provider "google" {
  mock_resource "google_project" {
    defaults = { number = "123456789012" }
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
    # The project starts empty and exports nothing to CI.
    condition     = local.children_cloud[0].exports == {}
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
