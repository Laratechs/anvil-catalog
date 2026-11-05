variable "name" {
  description = "Service and repository name."
  type        = string
}

variable "org" {
  description = "GitHub organization that owns the repository."
  type        = string
}

variable "description" {
  description = "Repository description."
  type        = string
  default     = ""
}

variable "visibility" {
  description = "Repository visibility: private or internal."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "internal"], var.visibility)
    error_message = "visibility must be private or internal."
  }
}

variable "archived" {
  description = "Archive the repository, making it read-only."
  type        = bool
  default     = false
}

variable "template" {
  description = "Template repository to create the repository from, as owner/name."
  type        = string

  validation {
    condition     = length(split("/", var.template)) == 2
    error_message = "template must be owner/name."
  }
}

variable "template_ref" {
  description = "Branch, tag or commit of the template that kept-in-sync files are read from."
  type        = string
  default     = "main"
}

variable "default_branch" {
  description = "Default branch of the template, where kept-in-sync files are committed."
  type        = string
  default     = "main"
}

variable "actions_variables" {
  description = "GitHub Actions repository variables, for example ANVIL_GCP_PROJECT."
  type        = map(string)
  default     = {}
}
