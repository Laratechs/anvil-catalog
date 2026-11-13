# Service orders with no clouds.
# tests/run.sh renders it and runs this file with mock providers.

mock_provider "github" {
  mock_data "github_repository_file" {
    defaults = { content = "# kept in sync\n.golangci.yml\n" }
  }
  mock_resource "github_repository" {
    defaults = { html_url = "https://github.com/Laratechs/orders" }
  }
}

run "apply" {
  assert {
    condition     = output.service.image == "ghcr.io/laratechs/orders" && output.service.repository_url == "https://github.com/Laratechs/orders"
    error_message = "service status: ${jsonencode(output.service)}"
  }
  assert {
    # CI's settings are committed after its variables, so the CLI can follow
    # the run that uses them.
    condition     = output.service.ci_commit != ""
    error_message = "ci_commit: ${output.service.ci_commit}"
  }
  assert {
    # Without -option template, the default: Go.
    condition     = module.service_repository.template == "Laratechs/anvil-template-go"
    error_message = "template: ${module.service_repository.template}"
  }
  assert {
    condition     = length(local.children_cloud) == 0
    error_message = "children: ${jsonencode(local.children_cloud)}"
  }
}
