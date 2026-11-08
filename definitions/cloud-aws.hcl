# An AWS account for one service in AWS Organizations.
cloud "aws" {
  title = "AWS account"

  # Where AWS accounts land: an aws binding names the organization's
  # account email and organizational unit
  # ("anvil binding create -provider=aws -set email_template=... NAME").
  # Everything the cloud needs says where, so it has no settings.
  binding {
    # Root email for each account; {service} is replaced with the service
    # name, and the result must be unique across AWS.
    email_template = string
    # Organizational unit for new accounts. Empty uses the root.
    parent_id  = optional(string, "")
    portal_url = optional(string, "https://console.aws.amazon.com/")
    region     = optional(string, "us-east-1")
  }

  provider "aws" {
    source = "hashicorp/aws"
    config = {
      region = binding.region
    }
  }

  component "account" {
    module = "../components/aws-account"
    inputs = {
      service        = anvil.name
      email_template = binding.email_template
      parent_id      = binding.parent_id
      portal_url     = binding.portal_url
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
