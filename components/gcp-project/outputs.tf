output "project" {
  value = {
    id          = google_project.this.project_id
    number      = google_project.this.number
    console_url = "https://console.cloud.google.com/home/dashboard?project=${google_project.this.project_id}"
  }
}

# What the repository's CI needs to publish images to the project.
output "ci" {
  value = {
    project                    = google_project.this.project_id
    region                     = var.region
    image                      = "${var.region}-docker.pkg.dev/${google_project.this.project_id}/${google_artifact_registry_repository.this.repository_id}/${var.service}"
    service_account            = google_service_account.ci.email
    workload_identity_provider = var.workload_identity_provider
  }
}
