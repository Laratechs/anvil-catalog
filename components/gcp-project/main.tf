# A GCP project for one Anvil service: the service's own cloud. Anvil
# creates it with what the service's CI needs to publish images there (an
# image repository and a CI identity) and nothing else. What runs in it,
# and how it is deployed, is the service team's.

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

locals {
  project_id = "${var.project_prefix}-${var.service}"
  # projects/N/locations/global/workloadIdentityPools/P/providers/X → the pool.
  pool = regex("^(projects/[^/]+/locations/global/workloadIdentityPools/[^/]+)/providers/[^/]+$", var.workload_identity_provider)[0]
  # Only workflows in the service's own repository can act as its CI.
  ci_principal = "principalSet://iam.googleapis.com/${local.pool}/attribute.repository/${var.repository}"
  labels = {
    managed-by    = "anvil"
    anvil-service = var.service
  }
}

resource "google_project" "this" {
  name            = var.service
  project_id      = local.project_id
  folder_id       = var.folder_id
  billing_account = var.billing_account
  # No default network: the team builds what it needs.
  auto_create_network = false
  # Anvil's force delete, with its typed confirmation, is the protection.
  # Deleting the project deletes everything in it, whoever created it.
  deletion_policy = "DELETE"
  labels          = local.labels
}

# Who the project is handed to. Without an owner only Anvil's own identity
# and whoever inherits access from the folder can use it.
resource "google_project_iam_member" "owner" {
  count   = var.owner != "" ? 1 : 0
  project = google_project.this.project_id
  role    = "roles/owner"
  member  = var.owner
}

# What CI needs: Artifact Registry for images, and the IAM Credentials API
# so the workflow's GitHub OIDC token can be exchanged for the CI identity.
resource "google_project_service" "ci" {
  for_each = toset(["artifactregistry.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com"])

  project = google_project.this.project_id
  service = each.key
  # The APIs go with the project; turning one off first could fail on
  # what the team built.
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "this" {
  project       = google_project.this.project_id
  location      = var.region
  repository_id = var.service
  format        = "DOCKER"
  description   = "Images of the ${var.service} service. Managed by Anvil."
  labels        = local.labels

  depends_on = [google_project_service.ci]
}

# Service account IDs need 6 to 30 characters; service names have 3 to 25.
resource "google_service_account" "ci" {
  project      = google_project.this.project_id
  account_id   = "ci-${var.service}"
  display_name = "${var.service} CI"
  description  = "Identity ${var.repository}'s CI publishes images with. Managed by Anvil. Grant it what your deploys need."

  depends_on = [google_project_service.ci]
}

resource "google_service_account_iam_member" "ci_impersonates" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.ci_principal
}

resource "google_artifact_registry_repository_iam_member" "ci_pushes" {
  project    = google_project.this.project_id
  location   = var.region
  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci.email}"
}
