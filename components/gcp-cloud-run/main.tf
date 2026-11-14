# A Cloud Run service for one Anvil service, in a shared project the
# platform team sets up (docs/gcp.md). Anvil creates the service's slot and
# identities; the service's CI builds, pushes and deploys new versions.

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
  # projects/N/locations/global/workloadIdentityPools/P/providers/X → the pool.
  pool = regex("^(projects/[^/]+/locations/global/workloadIdentityPools/[^/]+)/providers/[^/]+$", var.workload_identity_provider)[0]
  # Only workflows in the service's own repository can act as its deployer.
  ci_principal = "principalSet://iam.googleapis.com/${local.pool}/attribute.repository/${var.repository}"
  deployer     = "serviceAccount:${google_service_account.deployer.email}"
  labels = {
    managed-by    = "anvil"
    anvil-service = var.service
  }
}

# Each service has its own image repository: Artifact Registry grants are
# per repository, so a service's CI can push only its own images.
resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.region
  repository_id = var.service
  format        = "DOCKER"
  description   = "Images of the ${var.service} service. Managed by Anvil."
  labels        = local.labels
}

# Service account IDs need 6 to 30 characters; service names have 3 to 25.
resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "run-${var.service}"
  display_name = "${var.service} runtime"
  description  = "Identity the ${var.service} service runs as on Cloud Run. Managed by Anvil."
}

resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = "ci-${var.service}"
  display_name = "${var.service} CI"
  description  = "Identity ${var.repository}'s CI deploys with. Managed by Anvil."
}

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  location = var.region
  name     = var.service
  labels   = local.labels
  ingress  = "INGRESS_TRAFFIC_ALL"
  # Public services skip Cloud Run's invoker check, so anyone with the URL
  # can call them. Unlike granting allUsers the invoker role, this works
  # under a domain-restricted sharing policy.
  invoker_iam_disabled = var.public
  # Anvil's force delete, with its typed confirmation, is the protection.
  deletion_protection = false

  # Service-level scaling: Cloud Run's default, written out. The API
  # returns this block for every service, and the provider doesn't treat it
  # as computed, so leaving it out plans its removal on every re-apply.
  # The other attributes stay unset: the API reports them as 0 and "", which
  # the provider reads as unset, so they match.
  scaling {
    min_instance_count = 0
  }

  template {
    service_account = google_service_account.runtime.email
    containers {
      # A placeholder until CI deploys the service's first image.
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }

  lifecycle {
    # CI owns what runs: Terraform doesn't roll deploys back.
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
      # Environment variables and secret references: the service's
      # repository commits them and CI deploys them.
      template[0].containers[0].env,
      template[0].revision,
      template[0].labels,
      template[0].annotations,
    ]
  }
}

# Secret Manager names secrets by project number in resource names, which
# IAM conditions match against.
data "google_project" "this" {
  project_id = var.project_id
}

# The service's runtime identity reads the secrets named <service>-*, and
# no others. Teams create the secrets and write their values themselves
# (gcloud), so they don't exist when Anvil applies this: a conditional
# project-level grant covers them as they appear. The values never pass
# through Anvil or Terraform.
resource "google_project_iam_member" "runtime_reads_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.runtime.email}"

  condition {
    title       = "${var.service} secrets"
    description = "Secrets named ${var.service}-*. Managed by Anvil."
    expression  = "resource.name.startsWith(\"projects/${data.google_project.this.number}/secrets/${var.service}-\")"
  }
}

resource "google_service_account_iam_member" "ci_impersonates_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.ci_principal
}

resource "google_artifact_registry_repository_iam_member" "deployer_pushes" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.writer"
  member     = local.deployer
}

resource "google_cloud_run_v2_service_iam_member" "deployer_deploys" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.developer"
  member   = local.deployer
}

# Deploying a revision that runs as the runtime account needs actAs on it.
resource "google_service_account_iam_member" "deployer_acts_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = local.deployer
}
