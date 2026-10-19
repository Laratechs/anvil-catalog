variable "service" {
  description = "Anvil service name, used as the account name."
  type        = string
}

variable "team" {
  description = "Owning GitHub team slug, recorded as a tag."
  type        = string
}

variable "email_template" {
  description = "Root email for the new account, with {service} replaced by the service name, so it is unique across AWS."
  type        = string

  validation {
    condition     = strcontains(var.email_template, "{service}")
    error_message = "email_template must contain {service}: every AWS account needs a unique email."
  }
}

variable "parent_id" {
  description = "Organizational unit to place the account in. Empty uses the root."
  type        = string
  default     = ""
}

variable "group_display_name" {
  description = "IAM Identity Center group for the owning team."
  type        = string
}

variable "permission_set_arns" {
  description = "Permission sets assigned to the team's group on the account."
  type        = list(string)
}

variable "portal_url" {
  description = "IAM Identity Center access portal URL, returned to the requester."
  type        = string
  default     = "https://console.aws.amazon.com/"
}
