variable "service" {
  description = "Anvil service name, used as the project's display name and in its ID."
  type        = string
}

variable "project_prefix" {
  description = "Prefix of the project ID, which is <prefix>-<service>. Project IDs are unique across Google Cloud, so use one of your own."
  type        = string

  validation {
    # A service name is at most 25 characters and a project ID at most 30.
    condition     = can(regex("^[a-z][a-z0-9]{0,3}$", var.project_prefix))
    error_message = "project_prefix must be 1 to 4 lowercase letters and digits, starting with a letter, so <prefix>-<service> is a valid project ID."
  }
}

variable "folder_id" {
  description = "Folder the project is created in, as a number or folders/NUMBER."
  type        = string
}

variable "billing_account" {
  description = "Billing account the project is linked to, such as 000000-AAAAAA-000000."
  type        = string
}

variable "owner" {
  description = "IAM member granted roles/owner on the project, such as group:engineering@example.com. Empty grants nobody."
  type        = string
  default     = ""
}

variable "repository" {
  description = "The service's GitHub repository, as owner/name. Only its workflows can use the CI identity."
  type        = string
}

variable "region" {
  description = "Region of the service's image repository."
  type        = string
  default     = "us-central1"
}

variable "workload_identity_provider" {
  description = "Workload Identity Federation provider GitHub Actions authenticates with: projects/NUMBER/locations/global/workloadIdentityPools/POOL/providers/PROVIDER. It may live in another project, and must map attribute.repository = assertion.repository."
  type        = string
}
