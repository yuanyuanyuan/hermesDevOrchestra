#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGING_ROOT="${HERMES_STAGING_ROOT:-$REPO_ROOT/.hermes/staging}"

rm -rf "$STAGING_ROOT"
mkdir -p "$STAGING_ROOT/state" "$STAGING_ROOT/audit" "$STAGING_ROOT/project"

printf '%s\n' "staging_root=$STAGING_ROOT"
