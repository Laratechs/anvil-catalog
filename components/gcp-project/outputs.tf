output "project" {
  value = {
    id          = google_project.this.project_id
    number      = google_project.this.number
    console_url = "https://console.cloud.google.com/home/dashboard?project=${google_project.this.project_id}"
  }
}
