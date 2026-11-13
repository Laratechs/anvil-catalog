#!/usr/bin/env bash
# Tests this catalog's content: renders a service for each case below with
# "anvil catalog render", then runs terraform init, validate and test on it
# with the case's tests/cases/<case>.tftest.hcl. The tests use mock
# providers, so nothing is created and no credentials are needed, but the
# real providers are downloaded (once, into TF_PLUGIN_CACHE_DIR).
#
# Needs anvil and terraform on PATH. Runs every case, then exits non-zero
# if any failed. Run one case with: tests/run.sh gcp
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tests="$root/tests"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/anvil-catalog/terraform-plugins}"
# The rendered roots have no lock file and are thrown away, so Terraform
# may use the cache without recording checksums.
export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE=1
mkdir -p "$TF_PLUGIN_CACHE_DIR"

anvil version | sed -n 1p
terraform version | sed -n 1p

only="${1:-}"
failed=()

# check CASE SERVICE CLOUDS [render options...]
check() {
  local case=$1 name=$2 clouds=$3
  shift 3
  if [[ -n "$only" && "$only" != "$case" ]]; then
    return
  fi
  local dir="$work/$case" log="$work/$case.log"
  if {
    anvil catalog render -catalog "$root" -cloud "$clouds" -bindings "$tests/bindings.json" "$@" "$name" "$dir" &&
      cp "$tests/cases/$case.tftest.hcl" "$dir/" &&
      cd "$dir" &&
      terraform init -backend=false -input=false -no-color &&
      terraform validate -no-color &&
      terraform test -no-color -var-file=terraform.tfvars.json
  } >"$log" 2>&1; then
    echo "ok    $case"
  else
    echo "FAIL  $case"
    sed 's/^/      /' "$log"
    failed+=("$case")
  fi
  cd "$root"
}

check service orders ""
check gcp orders gcp
check aws orders aws
check gcpproject orders gcpproject
check aws-gcp orders aws,gcp
check short-name aaa aws,gcp
check private private gcp -settings "$tests/private.json"
check postgres orders gcp -addon postgres -instance-outputs "$tests/instance-outputs.json"
check postgres-instance postgres-gcp-test-ab12 gcp -instance postgres

if [[ -n "$only" && ! -f "$tests/cases/$only.tftest.hcl" ]]; then
  echo "no case $only" >&2
  exit 2
fi
if ((${#failed[@]})); then
  echo "failed: ${failed[*]}" >&2
  exit 1
fi
