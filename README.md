# anvil-catalog

What [Anvil](https://github.com/Laratechs/anvil) builds. Anvil is the engine:
it accepts requests, tracks services and their clouds, and runs Terraform.
This repository says what a **service** and each **cloud** are made of.

It was Anvil's built-in catalog (`catalog/` in the anvil repository) until
the split in Laratechs/anvil#11, and keeps that history. Tag `v0.1.0` is
the content anvil built in last.

| Path | What it is |
| --- | --- |
| `catalog.hcl` | The catalog contract version, and optionally the anvil and Terraform versions this catalog needs |
| `definitions/service.hcl` | A service: a GitHub repository created from a template repository, with CI that publishes an image and deploys it to the service's clouds |
| `definitions/cloud-gcp.hcl` | `cloud "gcp"`: a Cloud Run service in a shared project, with its own image repository and service accounts |
| `definitions/cloud-aws.hcl` | `cloud "aws"`: an AWS account in AWS Organizations |
| `components/*` | The Terraform modules the definitions use, each with an `anvil.json` of progress labels |
| `tests/` | Content tests: rendered services applied with mock providers |

The contract between Anvil and this repository (what a definition may
declare, what Anvil passes it and what it reads back) is
[docs/catalog-contract.md](https://github.com/Laratechs/anvil/blob/main/docs/catalog-contract.md)
in the anvil repository.

## How Anvil uses it

Every Anvil server names its catalog, pinned to a tag:

```hcl
catalog {
  source = "git::https://github.com/Laratechs/anvil-catalog.git?ref=v0.1.0"
}
```

Anvil fetches it as its GitHub App, which needs read access to this
repository. On every apply Anvil generates a root module with one module
block per component of the service's definitions, and records the catalog
revision on the service. A new tag reaches existing services the next time
each is applied.

Where clouds land (the shared GCP project, the AWS organization) is a
**cloud binding** an operator creates on the server, declared by each
cloud's `binding { }` block. How they are deployed is **settings**
(`settings "cloud_gcp" { public = false }` in the server's configuration).

## Releasing

Tag `main` as `vMAJOR.MINOR.PATCH` once CI passes, then point servers at the
new tag. Note changes that alter what an existing service's Terraform plans
in the tag's message. Module addresses are state: renaming a component or a
resource in a module moves or replaces it unless the module adds a `moved`
block. Anvil's upgrade scenario (`TestUpgrade` in its e2e harness) runs a
catalog against services created by an earlier one:

```
ANVIL_E2E_CATALOG=$PWD ANVIL_E2E=1 go test -C ../anvil ./e2e/ -v -run Upgrade -timeout 30m
```

## Testing

CI runs `terraform fmt -check` and `tests/run.sh`, which renders a service
for each case with `anvil catalog render` and runs `terraform init`,
`validate` and `test` on it, with the case's assertions in
`tests/cases/<case>.tftest.hcl`. The tests use mock providers, so they need
no credentials and create nothing, but they download the real providers.
`tests/bindings.json` holds the bindings the cases render with.

Locally, with Terraform and an anvil checkout beside this one:

```
go install -C ../anvil ./cmd/anvil
tests/run.sh          # every case
tests/run.sh gcp      # one case
```

CI builds anvil with the `setup-anvil` action from the anvil repository,
pinned to a commit. Move the pin forward when the catalog needs a newer
anvil, and set `requires_anvil` in `catalog.hcl` once that anvil is
released. The anvil repository is private, so its **Settings → Actions →
General → Access** must allow repositories in the organization; no token
is involved.

The e2e harness in the anvil repository tests this catalog against the
real binary, Terraform and GitHub; it runs the `anvil-catalog` checkout
beside anvil by default.
