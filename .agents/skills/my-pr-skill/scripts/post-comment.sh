#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: post-comment.sh --number=N [--body=TEXT|--body-file=FILE]

Post a comment on a PR (issue-level comment, not a review).

Options:
  --number=N       PR number (required).
  --body=TEXT      Comment body text.
  --body-file=FILE Read comment body from FILE.
  --help           Show this message.

Requires: gh CLI authenticated.
EOF
}

main() {
  local number=""
  local body=""
  local body_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --number=*)    number="${1#*=}"; shift ;;
      --body=*)      body="${1#*=}";   shift ;;
      --body-file=*) body_file="${1#*=}"; shift ;;
      --help)        usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  if [[ -z "$number" ]]; then
    echo "Error: --number is required." >&2
    usage >&2
    exit 1
  fi

  if [[ -n "$body_file" ]]; then
    gh pr comment "$number" --body-file "$body_file"
  else
    gh pr comment "$number" --body "$body"
  fi
}

main "$@"
