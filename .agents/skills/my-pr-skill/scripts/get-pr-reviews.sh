#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: get-pr-reviews.sh --number=N [--state=STATE] [--output=FILE] [--comments-output=FILE]

Fetch PR reviews and optionally review-level comments (line comments).

Options:
  --number=N          PR number (required).
  --state=STATE       Filter reviews by state (APPROVED, CHANGES_REQUESTED, COMMENTED, DISMISSED, PENDING).
                      If not specified, returns all reviews.
  --output=FILE       Write reviews JSON array to FILE.
  --comments-output=F Write review comments (line-level) JSON array to F.
  --help              Show this message.

Requires: gh CLI authenticated.
EOF
}

main() {
  local number=""
  local state=""
  local output=""
  local comments_output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --number=*)       number="${1#*=}"; shift ;;
      --state=*)        state="${1#*=}"; shift ;;
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

  # Validate state parameter if provided
  if [[ -n "$state" ]]; then
    case "$state" in
      APPROVED|CHANGES_REQUESTED|COMMENTED|DISMISSED|PENDING) ;;
      *) echo "Error: Invalid state '$state'. Must be one of: APPROVED, CHANGES_REQUESTED, COMMENTED, DISMISSED, PENDING" >&2; exit 1 ;;
    esac
  fi

  local owner repo
  owner=$(gh repo view --json owner --jq '.owner.login')
  repo=$(gh repo view --json name --jq '.name')

  if [[ -n "$output" ]]; then
    mkdir -p "$(dirname "$output")"
    local jq_filter
    if [[ -n "$state" ]]; then
      jq_filter="[.[] | select(.state == \"$state\") | {id: .id, state: .state, body: .body, user: .user.login, submitted_at: .submitted_at}]"
    else
      jq_filter="[.[] | {id: .id, state: .state, body: .body, user: .user.login, submitted_at: .submitted_at}]"
    fi
    gh api "repos/${owner}/${repo}/pulls/${number}/reviews" \
      --jq "$jq_filter" \
      > "$output"
  fi

  if [[ -n "$comments_output" ]]; then
    mkdir -p "$(dirname "$comments_output")"
    gh api "repos/${owner}/${repo}/pulls/${number}/comments" \
      --jq '[.[] | {id: .id, path: .path, line: .line, body: .body, user: .user.login}]' \
      > "$comments_output"
  fi
}

main "$@"
