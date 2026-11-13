# anvil-catalog

What [Anvil](https://github.com/Laratechs/anvil) builds. Anvil is the engine:
it accepts requests, tracks services and their clouds, and runs Terraform.
This repository says what a **service** and each **deployment** (where a
service runs) are made of.

It was Anvil's built-in catalog (`catalog/` in the anvil repository) until
the split in Laratechs/anvil#11, and keeps that history. Tag `v0.1.0` is
the content anvil built in last.

| Path | What it is |
| --- | --- |
| `catalog.hcl` | The catalog contract version, and optionally the anvil and Terraform versions this catalog needs |
| `definitions/service.hcl` | A service: a GitHub repository created from the template the requester chooses (see [Service templates](#service-templates)), with CI that publishes an image and deploys it to the service's clouds |
| `definitions/cloud-gcp.hcl` | `deployment "gcp"`: the platform-managed deployment, a Cloud Run service in a shared project, with its own image repository and service accounts |
| `definitions/cloud-aws.hcl` | `deployment "aws"`: a self-managed deployment, an AWS account in AWS Organizations (off for now: it can't be requested while no aws binding exists) |
| `definitions/deployment-gcpproject.hcl` | `deployment "gcpproject"`: the self-managed deployment, an empty GCP project of the service's own, created in the folder its binding names |
| `definitions/addon-postgres.hcl` | `addon "postgres"`: a PostgreSQL database for a service on the gcp deployment. A Cloud SQL instance per gcp binding is shared, and each service gets a database owned by its runtime identity, with IAM database authentication and no password |
| `components/*` | The Terraform modules the definitions use, each with an `anvil.json` of progress labels |
| `tests/` | Content tests: rendered services applied with mock providers |

The contract between Anvil and this repository (what a definition may
declare, what Anvil passes it and what it reads back) is Anvil's catalog
contract, version 3 (`contract = 3` in `catalog.hcl`), documented with
Anvil.

## Service templates

A new service's repository is copied from a template repository, which the
requester chooses with the service's `template` option:

```
anvil service create -option template=python orders
```

Without the option a service gets `go`. `anvil catalog show` lists the
templates on offer, and any other value is refused when it is requested.
The template is **fixed once the service has it**, the default included: a
service keeps the template it was created with, and asking for another is
refused. Its kept-in-sync files are read from that template for as long as
the service exists, so moving a service to another template isn't
offered.

| `template` | Repository | Stack | Checks in CI |
| --- | --- | --- | --- |
| `go` (default) | [`Laratechs/anvil-template-go`](https://github.com/Laratechs/anvil-template-go) | Go `net/http` | `go test -race`, `golangci-lint` with `gosec`, `govulncheck` |
| `python` | [`Laratechs/anvil-template-python`](https://github.com/Laratechs/anvil-template-python) | Python 3.14, FastAPI, uv | `pytest`, `ruff` with its bandit rules, `pip-audit` |
| `rust` | [`Laratechs/anvil-template-rust`](https://github.com/Laratechs/anvil-template-rust) | Rust, axum on tokio | `cargo test`, `clippy -D warnings`, `rustfmt`, `cargo deny` |
| `typescript` | [`Laratechs/anvil-template-typescript`](https://github.com/Laratechs/anvil-template-typescript) | Node.js 26, TypeScript, Fastify | `node --test`, `tsc`, `eslint` with security rules, `prettier`, `npm audit` |

Each template is a GitHub template repository with the same contract, so
every deployment works with any of them:

- a server that listens on `$PORT` (default `8080`), answers `/healthz`,
  stops cleanly on SIGTERM and logs JSON to stdout;
- a `Dockerfile` that takes the `SERVICE_NAME` build argument and runs as
  a non-root user;
- `.github/anvil-managed.txt`, listing the files Anvil keeps in sync (the
  CI workflow and the lint configuration);
- a CI workflow whose `build` job builds, tests, lints and scans the code
  in the template's language and builds the image once, and whose
  `publish`, `push` and `deploy` jobs are the same in every template.

The operator's `template_ref` setting names the ref every template's
kept-in-sync files are read from (default `main`).

**Adding a template:**

1. Create `Laratechs/anvil-template-<name>` as a GitHub template
   repository that meets the contract above, with its default branch
   `main`.
2. In `definitions/service.hcl`, add `<name>` to `choices.template` and
   `<name> = "Laratechs/anvil-template-<name>"` to the map passed to the
   repository component.
3. Add `tests/cases/template-<name>.tftest.hcl` and `<name>` to the
   template loop in `tests/run.sh`, add a row above, and release a tag.

Removing one is a breaking change: a service created from it fails its
next apply until the template is offered again, because Anvil keeps the
value a service stores rather than change it.

## How Anvil uses it

Every Anvil server names its catalog, pinned to a tag:

```hcl
catalog {
  source = "git::https://github.com/Laratechs/anvil-catalog.git?ref=v0.5.0"
}
```

The repository is public, so servers fetch it with no credentials. On
every apply Anvil generates a root module with one module
block per component of the service's definitions, and records the catalog
revision on the service. A new tag reaches existing services the next time
each is applied.

Where clouds land (the shared GCP project, the AWS organization) is a
**cloud binding** an operator creates on the server, declared by each
cloud's `binding { }` block. How they are deployed is **settings**
(`settings "cloud_gcp" { public = false }` in the server's configuration).

## Releasing

Tag `main` as `vMAJOR.MINOR.PATCH` once CI and `tests/run.sh` pass, then
point servers at the new tag (and anvil's CI, which tests the tag servers
run). Note changes that alter what an existing service's Terraform plans
in the tag's message. Module addresses are state: renaming a component or a
resource in a module moves or replaces it unless the module adds a `moved`
block. Anvil's upgrade scenario (`TestUpgrade` in its e2e harness) runs a
catalog against services created by an earlier one:

```
ANVIL_E2E_CATALOG=$PWD ANVIL_E2E=1 go test -C ../anvil ./e2e/ -v -run Upgrade -timeout 30m
```

## Testing

This repository's CI runs `terraform fmt -check` and `terraform validate`
on every component.

`tests/run.sh` tests what the definitions build: it renders a service for
each case with `anvil catalog render` and runs `terraform init`,
`validate` and `test` on it, with the case's assertions in
`tests/cases/<case>.tftest.hcl`. The tests use mock providers, so they need
no credentials and create nothing, but they download the real providers.
`tests/bindings.json` holds the bindings the cases render with. It needs
anvil, which is private, so it runs where anvil is: run it before tagging,
with Terraform and an anvil checkout beside this one,

```
go install -C ../anvil ./cmd/anvil
tests/run.sh          # every case
tests/run.sh gcp      # one case
```

and anvil's CI runs it against the tag servers run on every change to
anvil, and against `main` nightly. Set `requires_anvil` in `catalog.hcl`
when a change needs a newer anvil release.

Anvil's e2e harness also tests this catalog against the real binary,
Terraform and GitHub; it runs the `anvil-catalog` checkout beside anvil by
default.
