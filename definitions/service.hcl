# A service: a GitHub repository created from a template repository, with CI
# that publishes an image and deploys it to the service's clouds.
service {
  title = "Service"

  settings {
    # Container registry namespace CI publishes to.
    registry = optional(string, "ghcr.io/laratechs")
    # Ref of the templates that kept-in-sync files are read from.
    template_ref = optional(string, "main")
    visibility   = optional(string, "private")
  }

  options {
    # The template the service's repository is created from (README.md,
    # "Service templates"). Its kept-in-sync files are read from the same
    # template for as long as the service exists, so it is fixed: a
    # service keeps the one it was created with, the default included.
    template = optional(string, "go")
  }
  choices = {
    template = ["go", "python", "rust", "typescript"]
  }
  immutable = ["template"]

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
      template = {
        go         = "Laratechs/anvil-template-go"
        python     = "Laratechs/anvil-template-python"
        rust       = "Laratechs/anvil-template-rust"
        typescript = "Laratechs/anvil-template-typescript"
      }[options.template]
      template_ref = settings.template_ref
      actions_variables = merge(
        { ANVIL_IMAGE = lower("${settings.registry}/${anvil.name}") },
        children.deployment[*].exports...
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
