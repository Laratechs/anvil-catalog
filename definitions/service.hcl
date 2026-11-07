# A service: a GitHub repository created from a template repository, with CI
# that publishes an image and deploys it to the service's clouds.
service {
  title = "Service"

  settings {
    # Container registry namespace CI publishes to.
    registry = optional(string, "ghcr.io/laratechs")
    # Template repository new services are created from, as owner/name.
    template = optional(string, "Laratechs/anvil-template-go")
    # Ref of the template that kept-in-sync files are read from.
    template_ref = optional(string, "main")
    visibility   = optional(string, "private")
  }

  provider "github" {
    source = "integrations/github"
    config = {
      owner = anvil.org
    }
  }

  component "repository" {
    module = "../components/github-repository"
    inputs = {
      name         = anvil.name
      org          = anvil.org
      description  = anvil.description != "" ? anvil.description : "${anvil.name} service. Created by Anvil."
      visibility   = settings.visibility
      archived     = anvil.lifecycle == "archived"
      template     = settings.template
      template_ref = settings.template_ref
      actions_variables = merge(
        { ANVIL_IMAGE = lower("${settings.registry}/${anvil.name}") },
        children.cloud[*].exports...
      )
    }
  }

  status {
    repository_url = component.repository.repository_url
    image          = lower("${settings.registry}/${anvil.name}")
    # CI's run on this commit publishes, and deploys to any cloud, with the
    # variables above; the CLI waits for it.
    ci_commit = component.repository.ci_commit
  }

  lifecycle {
    # An archived repository is read-only: only the repository itself is
    # applied, so file changes are not attempted.
    archive_targets = ["repository.github_repository.this"]
    # A force delete forgets everything else (it goes with the repository)
    # and destroys the repository.
    destroy_on_delete = ["repository.github_repository.this"]
  }
}
