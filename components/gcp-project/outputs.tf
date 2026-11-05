output "project" {
  value = {
    provider    = "gcp"
    id          = google_project.this.project_id
    console_url = "https://console.cloud.google.com/home/dashboard?project=${google_project.this.project_id}"
  }
}
