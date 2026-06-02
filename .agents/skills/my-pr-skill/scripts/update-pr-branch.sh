#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: update-pr-branch.sh --number=N

Update a PR branch with the latest changes from its base branch.
This calls the GitHub "Update branch" API.

Options:
  --number=N   PR number (required).
  --help       Show this message.

Requires: gh CLI authenticated with write access to the PR branch.
EOF
}

main() {
  local number=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --number=*) number="${1#*=}"; shift ;;
      --help)     usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  if [[ -z "$number" ]]; then
    echo "Error: --number is required." >&2
    usage >&2
    exit 1
  fi

  local owner repo
  owner=$(gh repo view --json owner --jq '.owner.login')
  repo=$(gh repo view --json name --jq '.name')

  gh api "repos/${owner}/${repo}/pulls/${number}/update-branch" \
    --method PUT
}

main "$@"
