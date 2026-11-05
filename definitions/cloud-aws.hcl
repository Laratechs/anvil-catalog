# An AWS account for one service in AWS Organizations.
cloud "aws" {
  title = "AWS account"

  settings {
    region = optional(string, "us-east-1")
    # Root email for each account; {service} is replaced with the service
    # name, and the result must be unique across AWS.
    email_template = optional(string, "")
    # Organizational unit for new accounts. Empty uses the root.
    parent_id = optional(string, "")
    portal_url = optional(string, "https://console.aws.amazon.com/")
  }

  enabled_when = settings.email_template != ""

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
      email_template      = settings.email_template
      parent_id           = settings.parent_id
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
  }
}
