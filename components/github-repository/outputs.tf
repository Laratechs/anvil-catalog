output "repository_url" {
  value = github_repository.this.html_url
}

output "full_name" {
  value = github_repository.this.full_name
}

output "ci_commit" {
  description = "The commit that last changed .github/anvil-ci.env: CI's run on it uses the current Actions variables. Empty without variables."
  value       = try(data.github_repository_file.ci_settings[local.ci_settings_path].commit_sha, "")
}

output "template" {
  description = "The template repository the service was created from, and whose kept-in-sync files it gets, as owner/name."
  value       = var.template
}
