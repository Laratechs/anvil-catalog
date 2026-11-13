variable "name" {
  description = "Instance name: Anvil's name for this incarnation of the instance, unique because Cloud SQL keeps a deleted instance's name for about a week."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,96}[a-z0-9]$", var.name))
    error_message = "name must be lowercase letters, digits and hyphens, start with a letter and end with a letter or digit."
  }
}

variable "project_id" {
  description = "Shared project the instance runs in: the platform's."
  type        = string
}

variable "region" {
  description = "Region of the instance."
  type        = string
}

variable "tier" {
  description = "Machine tier, such as db-f1-micro or db-custom-2-7680."
  type        = string
}

variable "database_version" {
  description = "PostgreSQL version, such as POSTGRES_16."
  type        = string
}

variable "high_availability" {
  description = "Run a standby in a second zone of the region (REGIONAL availability)."
  type        = bool
}
