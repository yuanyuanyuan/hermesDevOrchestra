#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGING_ROOT="${HERMES_STAGING_ROOT:-$REPO_ROOT/.hermes/staging}"

rm -rf "$STAGING_ROOT"
printf '%s\n' "removed=$STAGING_ROOT"
