# A GCP project for one service: a cloud of the service's own. Anvil
# creates it empty, in the folder the platform team chose, and hands it
# over. What runs inside it, and how the service is deployed there, is the
# service team's.
#
# It is the self-managed deployment ("anvil service deploy
# -type=self-managed NAME"). A service has this or the platform-managed
# deployment in cloud-gcp.hcl, never both.
deployment "gcpproject" {
  type  = "self-managed"
  title = "GCP project"

  # Where projects are created: a gcpproject binding names the folder and
  # the billing account ("anvil binding create -provider=gcpproject
  # -set folder_id=... NAME").
  binding {
    # The folder new projects are created in, as a number or
    # folders/NUMBER. The platform team's policies on the folder apply to
    # every project in it.
    folder_id = string
    # The billing account projects are linked to.
    billing_account = string
    # Project IDs are <project_prefix>-<service>: 1 to 4 lowercase letters
    # and digits of your own, as IDs are unique across Google Cloud.
    project_prefix = string
    # An IAM member made owner of each project, such as
    # group:engineering@example.com. Empty leaves access to what the
    # folder grants.
    owner = optional(string, "")
  }

  # Creating a project needs no default project or region.
  provider "google" {
    source = "hashicorp/google"
  }

  component "project" {
    module = "../components/gcp-project"
    inputs = {
      service         = anvil.name
      project_prefix  = binding.project_prefix
      folder_id       = binding.folder_id
      billing_account = binding.billing_account
      owner           = binding.owner
    }
  }

  status {
    provider    = "gcpproject"
    kind        = "gcp_project"
    id          = component.project.project.id
    console_url = component.project.project.console_url
  }

  # No destroy_on_delete: Anvil never deletes a team's project, so a
  # service with one can't be archived or force deleted until the platform
  # team decommissions the project.
}
