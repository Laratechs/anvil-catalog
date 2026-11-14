output "service" {
  description = "The Cloud Run service, for Anvil's status."
  value = {
    id          = google_cloud_run_v2_service.this.id
    url         = google_cloud_run_v2_service.this.uri
    console_url = "https://console.cloud.google.com/run/detail/${var.region}/${google_cloud_run_v2_service.this.name}/metrics?project=${var.project_id}"
  }
}

output "ci" {
  description = "What the service's CI needs to push and deploy."
  value = {
    project                    = var.project_id
    region                     = var.region
    service                    = google_cloud_run_v2_service.this.name
    image                      = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}/${var.service}"
    service_account            = google_service_account.deployer.email
    workload_identity_provider = var.workload_identity_provider
  }
}

output "runtime_secrets" {
  description = "What the runtime identity may read in Secret Manager: the role and the condition limiting it to the service's own secrets."
  value = {
    role       = google_project_iam_member.runtime_reads_secrets.role
    expression = one(google_project_iam_member.runtime_reads_secrets.condition).expression
  }
}
