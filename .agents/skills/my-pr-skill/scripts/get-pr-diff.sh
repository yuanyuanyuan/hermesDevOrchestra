#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: get-pr-diff.sh --number=N [--output=FILE] [--files-output=FILE]

Fetch the diff of a GitHub PR and optionally extract changed file list.

Options:
  --number=N        PR number (required).
  --output=FILE     Write diff patch to FILE (default: stdout).
  --files-output=F  Write list of changed files to F (extracted from diff).
  --help            Show this message.

Requires: gh CLI authenticated.
EOF
}

main() {
  local number=""
  local output=""
  local files_output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --number=*)     number="${1#*=}"; shift ;;
      --output=*)     output="${1#*=}"; shift ;;
      --files-output=*) files_output="${1#*=}"; shift ;;
      --help)         usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  if [[ -z "$number" ]]; then
    echo "Error: --number is required." >&2
    usage >&2
    exit 1
  fi

  if [[ -n "$output" ]]; then
    mkdir -p "$(dirname "$output")"
    gh pr diff "$number" > "$output"
  else
    gh pr diff "$number"
  fi

  if [[ -n "$files_output" && -n "$output" ]]; then
    mkdir -p "$(dirname "$files_output")"
    grep -E '^\+\+\+ b/' "$output" 2>/dev/null | sed 's/+++ b\///' > "$files_output" || true
  fi
}

main "$@"
