output "instance" {
  description = "What tenants are created with: where the instance is, and the admin they connect as."
  value = {
    project_id            = var.project_id
    region                = var.region
    name                  = google_sql_database_instance.this.name
    connection_name       = google_sql_database_instance.this.connection_name
    admin_user            = google_sql_user.admin.name
    admin_service_account = google_service_account.admin.email
  }
  # The admin must be able to log in before a tenant is created.
  depends_on = [google_project_iam_member.admin, google_service_account_iam_member.anvil]
}
