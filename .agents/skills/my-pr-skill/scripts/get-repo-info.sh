#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: get-repo-info.sh [--owner|--repo|--json]

Prints repository information for the current git repository (detected by gh).

Options:
  --owner   Print only the owner login.
  --repo    Print only the repository name.
  --json    Print full JSON with owner and name.
  --help    Show this message.

Requires: gh CLI authenticated.
EOF
}

main() {
  local mode="json"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --owner) mode="owner"; shift ;;
      --repo)  mode="repo";  shift ;;
      --json)  mode="json";  shift ;;
      --help)  usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  case "$mode" in
    owner)
      gh repo view --json owner --jq '.owner.login'
      ;;
    repo)
      gh repo view --json name --jq '.name'
      ;;
    json)
      gh repo view --json owner,name --jq '{owner: .owner.login, repo: .name}'
      ;;
  esac
}

main "$@"
