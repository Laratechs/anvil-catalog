# A GCP project for one service: a cloud of the service's own. Anvil
# creates it in the folder the platform team chose, sets up what the
# service's CI needs to publish images there, and hands it over. What runs
# inside it, and how the service is deployed there, is the service team's.
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
    # Region of each project's image repository.
    region = optional(string, "us-central1")
    # Workload Identity Federation provider GitHub Actions authenticates
    # with, as the gcp binding's: one pool serves every project. It must
    # map attribute.repository = assertion.repository.
    workload_identity_provider = string
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
      service                    = anvil.name
      repository                 = "${anvil.org}/${anvil.name}"
      project_prefix             = binding.project_prefix
      folder_id                  = binding.folder_id
      billing_account            = binding.billing_account
      region                     = binding.region
      workload_identity_provider = binding.workload_identity_provider
      owner                      = binding.owner
    }
  }

  # Repository variables for CI: enough to authenticate and publish the
  # service's image to its project. There is no ANVIL_GCP_SERVICE, so the
  # template's deploy job doesn't run: delivery is the team's to build.
  exports = {
    ANVIL_GCP_PROJECT                    = component.project.ci.project
    ANVIL_GCP_REGION                     = component.project.ci.region
    ANVIL_GCP_IMAGE                      = component.project.ci.image
    ANVIL_GCP_SERVICE_ACCOUNT            = component.project.ci.service_account
    ANVIL_GCP_WORKLOAD_IDENTITY_PROVIDER = component.project.ci.workload_identity_provider
  }

  status {
    provider    = "gcpproject"
    kind        = "gcp_project"
    id          = component.project.project.id
    console_url = component.project.project.console_url
  }

  lifecycle {
    # A force delete deletes the project, and with it everything in it,
    # including what the team built. Anvil names it and asks first.
    destroy_on_delete = ["project"]
    # The whole project holds the team's data.
    stateful = ["project.google_project.this"]
  }
}
