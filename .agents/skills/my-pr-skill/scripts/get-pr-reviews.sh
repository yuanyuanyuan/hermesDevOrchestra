#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: get-pr-reviews.sh --number=N [--output=FILE] [--comments-output=FILE]

Fetch PR reviews and optionally review-level comments (line comments).

Options:
  --number=N          PR number (required).
  --output=FILE       Write reviews JSON array to FILE.
  --comments-output=F Write review comments (line-level) JSON array to F.
  --help              Show this message.

Requires: gh CLI authenticated.
EOF
}

main() {
  local number=""
  local output=""
  local comments_output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --number=*)       number="${1#*=}"; shift ;;
      --output=*)       output="${1#*=}"; shift ;;
      --comments-output=*) comments_output="${1#*=}"; shift ;;
      --help)           usage; exit 0 ;;
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
    gh api "repos/${owner}/${repo}/pulls/${number}/reviews" \
      --jq '.[] | {id: .id, state: .state, body: .body, user: .user.login, submitted_at: .submitted_at}' \
      > "$output"
  fi

  if [[ -n "$comments_output" ]]; then
    mkdir -p "$(dirname "$comments_output")"
    gh api "repos/${owner}/${repo}/pulls/${number}/comments" \
      --jq '.[] | {id: .id, path: .path, line: .line, body: .body, user: .user.login}' \
      > "$comments_output"
  fi
}

main "$@"
