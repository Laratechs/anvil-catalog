# A Cloud Run service for one service, in a shared project the platform team
# sets up (docs/gcp.md). Anvil creates the slot (the Cloud Run service, an
# image repository and two service accounts); the service's CI pushes
# images and deploys.
# It is the managed deployment: it runs on the platform, the shared
# infrastructure the platform team runs.
deployment "gcp" {
  type  = "platform-managed"
  title = "Cloud Run service"

  # Where Cloud Run services land: a gcp binding names the shared project
  # ("anvil binding create -provider=gcp -set project_id=... NAME").
  binding {
    # The shared project services run in.
    project_id = string
    region     = optional(string, "us-central1")
    # Workload Identity Federation provider GitHub Actions authenticates
    # with: projects/NUMBER/locations/global/workloadIdentityPools/POOL/providers/PROVIDER.
    # It must map attribute.repository = assertion.repository.
    workload_identity_provider = string
  }

  # How they are deployed, for every service.
  settings {
    # Whether services' URLs answer without authentication (so they open in
    # a browser) unless a service chooses otherwise with its public option.
    public = optional(bool, true)
  }

  # What a requester chooses for their own service
  # ("anvil service deploy -option public=false NAME").
  options {
    # Serve the URL without authentication. Unset follows settings.public.
    public = optional(bool)
  }

  provider "google" {
    source = "hashicorp/google"
    config = {
      project = binding.project_id
      region  = binding.region
    }
  }

  component "run" {
    module = "../components/gcp-cloud-run"
    inputs = {
      service                    = anvil.name
      repository                 = "${anvil.org}/${anvil.name}"
      project_id                 = binding.project_id
      region                     = binding.region
      workload_identity_provider = binding.workload_identity_provider
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
    destroy_on_delete = ["run"]
    # The image repository holds the images CI pushed; archive and force
    # delete destroy it with them.
    stateful = ["run.google_artifact_registry_repository.this"]
  }
}
