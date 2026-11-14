# A GitHub repository for one Anvil service, created from a template
# repository, with the template's kept-in-sync files. Services have no owning
# team: organization members get access from the org's base permission.

terraform {
  required_version = ">= 1.7"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

locals {
  template_owner = split("/", var.template)[0]
  template_name  = split("/", var.template)[1]
}

resource "github_repository" "this" {
  name        = var.name
  description = var.description
  visibility  = var.visibility
  archived    = var.archived

  has_wiki               = false
  has_projects           = false
  delete_branch_on_merge = true
  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = true

  topics = ["anvil-managed"]

  # The template is copied once, when the repository is created.
  template {
    owner                = local.template_owner
    repository           = local.template_name
    include_all_branches = false
  }

  lifecycle {
    # Deleting a service's repository is never done by an ordinary apply.
    prevent_destroy = true
    # Repositories that predate templates, or whose template changed, are
    # not recreated.
    ignore_changes = [template, auto_init]
  }
}

# Kept-in-sync files: the template lists paths the platform enforces after
# creation (lint configuration) in .github/anvil-managed.txt. They are
# read from the template at template_ref and committed when they differ, so
# a fix released in the template reaches every service.
#
# The CI workflow is not one of them. It is copied from the template once,
# when the service is created, and then belongs to the team.
data "github_repository_file" "managed_list" {
  repository = var.template
  file       = ".github/anvil-managed.txt"
  branch     = var.template_ref
}

locals {
  managed_paths = toset([
    for line in split("\n", data.github_repository_file.managed_list.content) :
    trimspace(line) if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ])
}

data "github_repository_file" "synced" {
  for_each = local.managed_paths

  repository = var.template
  file       = each.key
  branch     = var.template_ref
}

resource "github_repository_file" "synced" {
  for_each = local.managed_paths

  repository          = github_repository.this.name
  branch              = var.default_branch
  file                = each.key
  content             = data.github_repository_file.synced[each.key].content
  commit_message      = "Update Anvil-managed ${each.key}"
  overwrite_on_create = true
}

# This resource was called "managed" while the CI workflow was on the list.
# A service created then has github_repository_file.managed[".github/workflows/ci.yml"]
# in its state, and with the workflow off the list Terraform would plan to
# destroy it, deleting the team's file. So the lint configuration of each
# template moves to "synced", and whatever is left in "managed" (the
# workflow) is forgotten without being destroyed: every file stays where it
# is, and the plan has nothing to add, change or destroy. A moved block
# whose path a service doesn't have is ignored. Drop these blocks once no
# service state holds the old resource.
moved {
  from = github_repository_file.managed[".golangci.yml"]
  to   = github_repository_file.synced[".golangci.yml"]
}

moved {
  from = github_repository_file.managed["ruff.toml"]
  to   = github_repository_file.synced["ruff.toml"]
}

moved {
  from = github_repository_file.managed["rustfmt.toml"]
  to   = github_repository_file.synced["rustfmt.toml"]
}

moved {
  from = github_repository_file.managed["deny.toml"]
  to   = github_repository_file.synced["deny.toml"]
}

moved {
  from = github_repository_file.managed["eslint.config.js"]
  to   = github_repository_file.synced["eslint.config.js"]
}

moved {
  from = github_repository_file.managed[".prettierrc.json"]
  to   = github_repository_file.synced[".prettierrc.json"]
}

removed {
  from = github_repository_file.managed

  lifecycle {
    destroy = false
  }
}

resource "github_actions_variable" "this" {
  for_each = var.actions_variables

  repository    = github_repository.this.name
  variable_name = each.key
  value         = each.value
}

# A copy of the Actions variables, committed after they are set. Variables
# alone don't run CI, so a new service, or one given a cloud, would wait
# for its next merge to publish and deploy. This commit is a push to the
# default branch: CI runs on it with the new variables, and its SHA lets
# the CLI follow that run (status ci_commit).
locals {
  ci_settings_path = ".github/anvil-ci.env"
}

resource "github_repository_file" "ci_settings" {
  # Keyed by path, which progress shows ("committing .github/anvil-ci.env").
  for_each = length(var.actions_variables) > 0 ? toset([local.ci_settings_path]) : toset([])

  repository = github_repository.this.name
  branch     = var.default_branch
  file       = each.key
  content = join("\n", concat([
    "# Written by Anvil: the Actions variables it sets on this repository.",
    "# Anvil commits this file when they change, so CI runs (and deploys) with",
    "# them. Edits are overwritten.",
  ], [for k in sort(keys(var.actions_variables)) : "${k}=${var.actions_variables[k]}"], [""]))
  commit_message      = "Update Anvil's CI settings"
  overwrite_on_create = true

  # After the variables, so the run this commit starts sees them, and after
  # the managed files, so it runs the current CI.
  depends_on = [github_actions_variable.this, github_repository_file.synced]
}

# The commit that last changed the file. The resource's own commit_sha is
# only set on create, so after an update it names the previous commit (whose
# CI run the new one cancels); reading the file back after the change gets
# the current one.
data "github_repository_file" "ci_settings" {
  for_each = github_repository_file.ci_settings

  repository = github_repository.this.name
  branch     = each.value.branch
  file       = each.value.file

  depends_on = [github_repository_file.ci_settings]
}
