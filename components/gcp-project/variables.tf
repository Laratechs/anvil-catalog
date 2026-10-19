variable "service" {
  description = "Anvil service name."
  type        = string
}

variable "team" {
  description = "Owning GitHub team slug, recorded as a label."
  type        = string
}

variable "folder_id" {
  description = "Numeric folder ID to create the project in. Takes precedence over org_id."
  type        = string
  default     = ""
}

variable "org_id" {
  description = "Numeric organization ID, used when folder_id is empty."
  type        = string
  default     = ""
}

variable "billing_account" {
  description = "Billing account ID (XXXXXX-XXXXXX-XXXXXX). Empty leaves billing unlinked."
  type        = string
  default     = ""
}

variable "team_member" {
  description = "IAM member for the owning team, for example group:payments@laratechs.com."
  type        = string
}

variable "roles" {
  description = "Roles granted to team_member on the project."
  type        = list(string)
  default     = ["roles/editor"]
}

variable "enabled_apis" {
  description = "APIs to enable on the project."
  type        = list(string)
  default     = []
}
