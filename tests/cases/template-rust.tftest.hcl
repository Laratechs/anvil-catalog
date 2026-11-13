# Service orders created from the rust template (-option template=rust).
# tests/run.sh renders it and runs this file with mock providers.

mock_provider "github" {
  mock_data "github_repository_file" {
    defaults = { content = "# kept in sync\n.github/workflows/ci.yml\n" }
  }
  mock_resource "github_repository" {
    defaults = { html_url = "https://github.com/Laratechs/orders" }
  }
}

run "apply" {
  assert {
    # The repository is created from the template, and its kept-in-sync
    # files are read from the same one.
    condition     = module.service_repository.template == "Laratechs/anvil-template-rust"
    error_message = "template: ${module.service_repository.template}"
  }
}
