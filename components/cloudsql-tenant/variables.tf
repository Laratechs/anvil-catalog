variable "service" {
  description = "Anvil service name. Names the database, and the runtime identity (run-<service>) that owns it."
  type        = string
}

variable "project_id" {
  description = "Project the instance and the service's runtime identity are in: the platform's."
  type        = string
}

variable "instance" {
  description = "Name of the Cloud SQL instance."
  type        = string
}

variable "admin_user" {
  description = "The instance admin's PostgreSQL role, which creates the database."
  type        = string
}
