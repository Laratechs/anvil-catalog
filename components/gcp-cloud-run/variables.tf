variable "service" {
  description = "Anvil service name. Names the Cloud Run service and image repository."
  type        = string
}

variable "repository" {
  description = "The service's GitHub repository, as owner/name. Only its workflows can deploy."
  type        = string
}

variable "project_id" {
  description = "Shared project the service runs in."
  type        = string
}

variable "region" {
  description = "Region of the Cloud Run service and image repository."
  type        = string
}

variable "public" {
  description = "Serve requests without authentication: anyone with the URL can call the service."
  type        = bool
  default     = false
}

variable "workload_identity_provider" {
  description = "Workload Identity Federation provider GitHub Actions authenticates with: projects/NUMBER/locations/global/workloadIdentityPools/POOL/providers/PROVIDER. It must map attribute.repository."
  type        = string

  validation {
    condition     = can(regex("^projects/[^/]+/locations/global/workloadIdentityPools/[^/]+/providers/[^/]+$", var.workload_identity_provider))
    error_message = "workload_identity_provider must be projects/NUMBER/locations/global/workloadIdentityPools/POOL/providers/PROVIDER."
  }
}
