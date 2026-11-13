# One service's tenant on the postgres add-on's shared instance: a
# database of its own, owned by the service's runtime identity, which logs
# in with IAM database authentication. No other tenant can connect to it,
# and no password exists. A detach or force delete drops the database with
# its data.
#
# The google provider is the service's deployment's (the platform's
# project); postgresql connects to the instance as its admin.

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    postgresql = {
      source = "cyrilgdn/postgresql"
    }
  }
}

locals {
  # The runtime identity the gcp deployment creates for the service.
  runtime_email = "run-${var.service}@${var.project_id}.iam.gserviceaccount.com"
  # PostgreSQL names an IAM service account's role by its email without
  # the domain suffix.
  user = trimsuffix(local.runtime_email, ".gserviceaccount.com")
}

resource "google_sql_user" "runtime" {
  project  = var.project_id
  instance = var.instance
  name     = local.user
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_project_iam_member" "runtime" {
  for_each = toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${local.runtime_email}"

  condition {
    title      = "${var.instance} only"
    expression = "resource.name == \"projects/${var.project_id}/instances/${var.instance}\" && resource.service == \"sqladmin.googleapis.com\""
  }
}

# The admin must be a member of a role to make it a database's owner.
resource "postgresql_grant_role" "admin" {
  role       = var.admin_user
  grant_role = google_sql_user.runtime.name
}

resource "postgresql_database" "this" {
  name       = var.service
  owner      = google_sql_user.runtime.name
  depends_on = [postgresql_grant_role.admin]
}

# Every role may connect to a new database until this revokes it: only its
# owner (and the admin) can.
resource "postgresql_grant" "public" {
  database    = postgresql_database.this.name
  role        = "public"
  object_type = "database"
  privileges  = []
}
