variable "service" {
  description = "Anvil service name."
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

variable "enabled_apis" {
  description = "APIs to enable on the project."
  type        = list(string)
  default     = []
}
