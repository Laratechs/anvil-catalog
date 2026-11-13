output "database" {
  description = "The service's database, and the user it connects as."
  value = {
    name = postgresql_database.this.name
    user = google_sql_user.runtime.name
  }
  depends_on = [postgresql_grant.public, google_project_iam_member.runtime]
}
