# The postgres add-on's shared instance: one Cloud SQL for PostgreSQL
# instance per gcp binding, which every service that attaches the add-on
# has a tenant on. Anvil creates it with the first tenant and destroys it
# with the last, so it has no deletion protection.
#
# Nothing here has a password. Tenants are created over IAM database
# authentication by an admin service account that Anvil's own identity
# impersonates, and services connect as their runtime identity.

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

locals {
  labels = {
    managed-by  = "anvil"
    anvil-addon = "postgres"
  }
  # Service account IDs need 6 to 30 characters; the instance's name is
  # longer, so the admin's is derived from it.
  admin_id = "pgadmin-${substr(sha1(var.name), 0, 12)}"
}

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  region              = var.region
  name                = var.name
  database_version    = var.database_version
  deletion_protection = false

  settings {
    tier              = var.tier
    edition           = "ENTERPRISE"
    availability_type = var.high_availability ? "REGIONAL" : "ZONAL"
    user_labels       = local.labels

    # A public IP with no authorized networks: only the Cloud SQL
    # connectors reach it, authenticated by IAM, over TLS.
    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
  }
}

# The identity tenants are created with: an IAM database user in
# cloudsqlsuperuser, which Anvil impersonates.
resource "google_service_account" "admin" {
  project      = var.project_id
  account_id   = local.admin_id
  display_name = "postgres add-on admin (${var.name})"
  description  = "Creates tenants on Cloud SQL instance ${var.name}. Managed by Anvil."
}

resource "google_sql_user" "admin" {
  project        = var.project_id
  instance       = google_sql_database_instance.this.name
  name           = trimsuffix(google_service_account.admin.email, ".gserviceaccount.com")
  type           = "CLOUD_IAM_SERVICE_ACCOUNT"
  database_roles = ["cloudsqlsuperuser"]
}

resource "google_project_iam_member" "admin" {
  for_each = toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])
  project  = var.project_id
  role     = each.value
  member   = google_service_account.admin.member

  condition {
    title      = "${var.name} only"
    expression = "resource.name == \"projects/${var.project_id}/instances/${var.name}\" && resource.service == \"sqladmin.googleapis.com\""
  }
}

# Anvil's own identity, whatever runs Terraform, impersonates the admin.
data "google_client_openid_userinfo" "anvil" {}

resource "google_service_account_iam_member" "anvil" {
  service_account_id = google_service_account.admin.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member = endswith(data.google_client_openid_userinfo.anvil.email, ".gserviceaccount.com") ? (
    "serviceAccount:${data.google_client_openid_userinfo.anvil.email}"
  ) : "user:${data.google_client_openid_userinfo.anvil.email}"
}
