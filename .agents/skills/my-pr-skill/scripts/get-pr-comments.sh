#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: get-pr-comments.sh --number=N [--output=FILE]

Fetch issue-level comments on a PR (the discussion comments below the PR body).

Options:
  --number=N    PR number (required).
  --output=FILE Write comments JSON array to FILE.
  --help        Show this message.

Requires: gh CLI authenticated.
EOF
}

main() {
  local number=""
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --number=*) number="${1#*=}"; shift ;;
      --output=*) output="${1#*=}"; shift ;;
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

  if [[ -n "$output" ]]; then
    mkdir -p "$(dirname "$output")"
    gh api "repos/${owner}/${repo}/issues/${number}/comments" \
      --jq '.[] | {id: .id, body: .body, user: .user.login, created_at: .created_at}' \
      > "$output"
  else
    gh api "repos/${owner}/${repo}/issues/${number}/comments" \
      --jq '.[] | {id: .id, body: .body, user: .user.login, created_at: .created_at}'
  fi
}

main "$@"
