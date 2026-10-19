# A GCP project for one Anvil service, with the owning team's Google group
# granted IAM roles on it.

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Project IDs are global and stay reserved after deletion, so add a suffix.
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  project_id = "${trimsuffix(substr(var.service, 0, 25), "-")}-${random_string.suffix.result}"
}

resource "google_project" "this" {
  project_id      = local.project_id
  name            = var.service
  folder_id       = var.folder_id != "" ? var.folder_id : null
  org_id          = var.folder_id == "" ? var.org_id : null
  billing_account = var.billing_account != "" ? var.billing_account : null

  auto_create_network = false
  deletion_policy     = "PREVENT"

  labels = {
    managed-by    = "anvil"
    anvil-service = var.service
    anvil-team    = var.team
  }

  lifecycle {
    precondition {
      condition     = var.folder_id != "" || var.org_id != ""
      error_message = "Set folder_id or org_id."
    }
  }
}

resource "google_project_service" "this" {
  for_each = toset(var.enabled_apis)

  project            = google_project.this.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_iam_member" "team" {
  for_each = toset(var.roles)

  project = google_project.this.project_id
  role    = each.value
  member  = var.team_member
}
