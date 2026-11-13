# The postgres add-on's shared instance on the gcp-test binding.
# tests/run.sh renders it with "anvil catalog render -instance=postgres"
# and runs this file with mock providers.

mock_provider "google" {
  mock_resource "google_sql_database_instance" {
    defaults = {
      connection_name = "shared:us-central1:postgres-gcp-test-ab12"
    }
  }
  mock_resource "google_service_account" {
    defaults = {
      name   = "projects/shared/serviceAccounts/pgadmin-0123456789ab@shared.iam.gserviceaccount.com"
      email  = "pgadmin-0123456789ab@shared.iam.gserviceaccount.com"
      member = "serviceAccount:pgadmin-0123456789ab@shared.iam.gserviceaccount.com"
    }
  }
  mock_data "google_client_openid_userinfo" {
    defaults = {
      email = "anvil@ops.iam.gserviceaccount.com"
    }
  }
}

run "apply" {
  assert {
    condition = alltrue([
      output.instance.connection_name == "shared:us-central1:postgres-gcp-test-ab12",
      output.instance.name == "postgres-gcp-test-ab12",
      output.instance.project_id == "shared",
      output.instance.admin_user == "pgadmin-0123456789ab@shared.iam",
      output.instance.admin_service_account == "pgadmin-0123456789ab@shared.iam.gserviceaccount.com",
    ])
    error_message = "instance outputs don't match"
  }
}
