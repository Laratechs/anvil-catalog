# A Cloud Run service for one service, in a shared project the platform team
# sets up and configures here (docs/gcp.md). Anvil creates the slot (the
# Cloud Run service, an image repository and two service accounts); the
# service's CI pushes images and deploys.
cloud "gcp" {
  title = "Cloud Run service"

  settings {
    # The shared project services run in.
    project_id = optional(string, "")
    region     = optional(string, "us-central1")
    # Workload Identity Federation provider GitHub Actions authenticates
    # with: projects/NUMBER/locations/global/workloadIdentityPools/POOL/providers/PROVIDER.
    # It must map attribute.repository = assertion.repository.
    workload_identity_provider = optional(string, "")
    # Whether services' URLs answer without authentication (so they open in
    # a browser) unless a service chooses otherwise with its public option.
    public = optional(bool, true)
  }

  # What a requester chooses for their own service
  # ("anvil cloud create -option public=false ...").
  options {
    # Serve the URL without authentication. Unset follows settings.public.
    public = optional(bool)
  }

  enabled_when = settings.project_id != "" && settings.workload_identity_provider != ""

  provider "google" {
    source = "hashicorp/google"
  }

  component "run" {
    module = "../components/gcp-cloud-run"
    inputs = {
      service                    = anvil.name
      repository                 = "${anvil.org}/${anvil.name}"
      project_id                 = settings.project_id
      region                     = settings.region
      workload_identity_provider = settings.workload_identity_provider
      public                     = options.public != null ? options.public : settings.public
    }
  }

  # Repository variables for CI (the template's deploy job runs when they
  # are set).
  exports = {
    ANVIL_GCP_PROJECT                    = component.run.ci.project
    ANVIL_GCP_REGION                     = component.run.ci.region
    ANVIL_GCP_SERVICE                    = component.run.ci.service
    ANVIL_GCP_IMAGE                      = component.run.ci.image
    ANVIL_GCP_SERVICE_ACCOUNT            = component.run.ci.service_account
    ANVIL_GCP_WORKLOAD_IDENTITY_PROVIDER = component.run.ci.workload_identity_provider
  }

  status {
    provider    = "gcp"
    kind        = "cloud_run_service"
    id          = component.run.service.id
    url         = component.run.service.url
    public      = options.public != null ? options.public : settings.public
    console_url = component.run.service.console_url
  }

  lifecycle {
    # A force delete destroys the service's whole slot: the Cloud Run
    # service, its images and its service accounts.
    keep_on_delete = ["run"]
  }
}
