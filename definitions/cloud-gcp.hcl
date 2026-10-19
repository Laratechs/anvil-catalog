# A GCP project for one service, with the owning team's group granted roles.
cloud "gcp" {
  title = "GCP project"

  settings {
    # Numeric folder to create projects in. Takes precedence over org_id.
    folder_id = optional(string, "")
    org_id    = optional(string, "")
    # Billing account (XXXXXX-XXXXXX-XXXXXX). Empty leaves billing unlinked.
    billing_account = optional(string, "")
    # IAM member for a team; {team} is replaced with the team slug.
    member_template = optional(string, "group:{team}@laratechs.com")
    roles           = optional(list(string), ["roles/editor"])
    enabled_apis    = optional(list(string), [])
  }

  # GCP is offered only where a folder or organization is configured.
  enabled_when = settings.folder_id != "" || settings.org_id != ""

  provider "google" {
    source = "hashicorp/google"
  }

  provider "random" {
    source = "hashicorp/random"
  }

  component "project" {
    module = "../components/gcp-project"
    inputs = {
      service         = anvil.name
      team            = anvil.team
      folder_id       = settings.folder_id
      org_id          = settings.org_id
      billing_account = settings.billing_account
      team_member     = replace(settings.member_template, "{team}", anvil.team)
      roles           = settings.roles
      enabled_apis    = settings.enabled_apis
    }
  }

  exports = {
    ANVIL_GCP_PROJECT = component.project.project.id
  }

  status {
    provider    = "gcp"
    kind        = "gcp_project"
    id          = component.project.project.id
    console_url = component.project.project.console_url
    grants      = component.project.project.grants
  }
}
