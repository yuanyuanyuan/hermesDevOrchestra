#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: submit-review.sh --number=N --event=EVENT [--body=TEXT|--body-file=FILE]

Submit a PR review via the GitHub API.

Options:
  --number=N       PR number (required).
  --event=EVENT    Review event: REQUEST_CHANGES | COMMENT | APPROVE.
  --body=TEXT      Review body text.
  --body-file=FILE Read review body from FILE.
  --help           Show this message.

Note: GitHub does not allow a PR author to APPROVE their own PR.
      Callers should use COMMENT + approved wording instead.

Requires: gh CLI authenticated with pull_requests:write scope.
EOF
}

main() {
  local number=""
  local event=""
  local body=""
  local body_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --number=*)     number="${1#*=}"; shift ;;
      --event=*)      event="${1#*=}";  shift ;;
      --body=*)       body="${1#*=}";   shift ;;
      --body-file=*)  body_file="${1#*=}"; shift ;;
      --help)         usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  if [[ -z "$number" || -z "$event" ]]; then
    echo "Error: --number and --event are required." >&2
    usage >&2
    exit 1
  fi

  local owner repo
  owner=$(gh repo view --json owner --jq '.owner.login')
  repo=$(gh repo view --json name --jq '.name')

  local body_arg=""
  if [[ -n "$body_file" ]]; then
    body_arg="$(cat "$body_file")"
  else
    body_arg="$body"
  fi

  gh api "repos/${owner}/${repo}/pulls/${number}/reviews" \
    --method POST \
    --field "event=${event}" \
    --field "body=${body_arg}"
}

main "$@"
