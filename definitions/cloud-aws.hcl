# An AWS account for one service in AWS Organizations, with the owning team's
# IAM Identity Center group assigned permission sets.
cloud "aws" {
  title = "AWS account"

  settings {
    region = optional(string, "us-east-1")
    # Root email for each account; {service} is replaced with the service
    # name, and the result must be unique across AWS.
    email_template = optional(string, "")
    # Organizational unit for new accounts. Empty uses the root.
    parent_id = optional(string, "")
    # IAM Identity Center group for a team; {team} is replaced.
    group_template      = optional(string, "{team}")
    permission_set_arns = optional(list(string), [])
    portal_url          = optional(string, "https://console.aws.amazon.com/")
  }

  enabled_when = settings.email_template != "" && length(settings.permission_set_arns) > 0

  provider "aws" {
    source = "hashicorp/aws"
    config = {
      region = settings.region
    }
  }

  component "account" {
    module = "../components/aws-account"
    inputs = {
      service             = anvil.name
      team                = anvil.team
      email_template      = settings.email_template
      parent_id           = settings.parent_id
      group_display_name  = replace(settings.group_template, "{team}", anvil.team)
      permission_set_arns = settings.permission_set_arns
      portal_url          = settings.portal_url
    }
  }

  exports = {
    ANVIL_AWS_ACCOUNT = component.account.project.id
  }

  status {
    provider    = "aws"
    kind        = "aws_account"
    id          = component.account.project.id
    console_url = component.account.project.console_url
    grants      = component.account.project.grants
  }
}
