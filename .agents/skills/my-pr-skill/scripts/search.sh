#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: search.sh --type=TYPE --query=Q [--repo=OWNER/REPO]

Search code or issues in a GitHub repository.

Options:
  --type=TYPE   Search type: code | issues (required).
  --query=Q     Search query string (required).
  --repo=R      Limit to repo OWNER/NAME (default: detected from cwd).
  --help        Show this message.

Requires: gh CLI authenticated.
EOF
}

main() {
  local type=""
  local query=""
  local repo=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type=*)  type="${1#*=}";  shift ;;
      --query=*) query="${1#*=}"; shift ;;
      --repo=*)  repo="${1#*=}";  shift ;;
      --help)    usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  if [[ -z "$type" || -z "$query" ]]; then
    echo "Error: --type and --query are required." >&2
    usage >&2
    exit 1
  fi

  if [[ -z "$repo" ]]; then
    local owner detected_repo
    owner=$(gh repo view --json owner --jq '.owner.login')
    detected_repo=$(gh repo view --json name --jq '.name')
    repo="${owner}/${detected_repo}"
  fi

  case "$type" in
    code)
      gh search code "$query" --repo "$repo"
      ;;
    issues)
      gh search issues "$query" --repo "$repo"
      ;;
    *)
      echo "Error: unknown type '$type'. Use 'code' or 'issues'." >&2
      exit 1
      ;;
  esac
}

main "$@"
