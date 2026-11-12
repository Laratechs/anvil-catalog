# A GCP project for one Anvil service: the service's own cloud. Anvil
# creates it empty; what runs inside is the service team's.

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

resource "google_project" "this" {
  name            = var.service
  project_id      = "${var.project_prefix}-${var.service}"
  folder_id       = var.folder_id
  billing_account = var.billing_account
  # No default network: the team builds what it needs.
  auto_create_network = false
  # Anvil never deletes a team's project.
  deletion_policy = "PREVENT"

  labels = {
    managed-by    = "anvil"
    anvil-service = var.service
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Who the project is handed to. Without an owner only Anvil's own identity
# and whoever inherits access from the folder can use it.
resource "google_project_iam_member" "owner" {
  count   = var.owner != "" ? 1 : 0
  project = google_project.this.project_id
  role    = "roles/owner"
  member  = var.owner
}
