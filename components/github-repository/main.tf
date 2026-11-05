# A GitHub repository for one Anvil service, created from a template
# repository, with the template's kept-in-sync files. Services have no owning
# team: organization members get access from the org's base permission.

terraform {
  required_version = ">= 1.6"
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
# creation (CI, lint configuration) in .github/anvil-managed.txt. They are
# read from the template at template_ref and committed when they differ, so
# a fix released in the template reaches every service.
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

data "github_repository_file" "managed" {
  for_each = local.managed_paths

  repository = var.template
  file       = each.key
  branch     = var.template_ref
}

resource "github_repository_file" "managed" {
  for_each = local.managed_paths

  repository          = github_repository.this.name
  branch              = var.default_branch
  file                = each.key
  content             = data.github_repository_file.managed[each.key].content
  commit_message      = "Update Anvil-managed ${each.key}"
  overwrite_on_create = true
}

resource "github_actions_variable" "this" {
  for_each = var.actions_variables

  repository    = github_repository.this.name
  variable_name = each.key
  value         = each.value
}
