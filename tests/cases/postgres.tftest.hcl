# Service orders with the gcp deployment and the postgres add-on, rendered
# with the instance outputs in tests/instance-outputs.json. tests/run.sh
# runs this file with mock providers.

mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/shared/serviceAccounts/run-orders@shared.iam.gserviceaccount.com"
      email = "run-orders@shared.iam.gserviceaccount.com"
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

mock_provider "postgresql" {}

run "apply" {
  assert {
    # CI connects as the runtime identity, to the database named for the
    # service, with the Cloud SQL connector.
    condition = alltrue([
      local.cloud_gcp_exports.ANVIL_DB_INSTANCE == "shared:us-central1:postgres-gcp-test-ab12",
      local.cloud_gcp_exports.ANVIL_DB_NAME == "orders",
      local.cloud_gcp_exports.ANVIL_DB_USER == "run-orders@shared.iam",
      local.cloud_gcp_exports.ANVIL_GCP_SERVICE == "orders",
    ])
    error_message = "exports: ${jsonencode(local.cloud_gcp_exports)}"
  }
  assert {
    condition     = local.addon_postgres_exports.ANVIL_DB_NAME == "orders"
    error_message = "add-on exports: ${jsonencode(local.addon_postgres_exports)}"
  }
}
