#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: resolve-thread.sh --thread-id=N --resolve | --unresolve [--number=N]

Resolve or unresolve a PR review thread (conversation).

Options:
  --thread-id=N    The review comment ID (= thread ID) (required).
  --resolve        Mark the thread as resolved.
  --unresolve      Mark the thread as unresolved.
  --number=N       PR number. If omitted, auto-detected from current git branch.
  --help           Show this message.

Requires: gh CLI authenticated with pull_requests:write permission.
EOF
}

main() {
  local thread_id=""
  local action=""  # "resolve" or "unresolve"
  local number=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --thread-id=*)  thread_id="${1#*=}"; shift ;;
      --number=*)     number="${1#*=}"; shift ;;
      --resolve)      action="resolve"; shift ;;
      --unresolve)    action="unresolve"; shift ;;
      --help)         usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  if [[ -z "$thread_id" ]]; then
    echo "Error: --thread-id is required." >&2
    usage >&2
    exit 1
  fi

  if [[ -z "$action" ]]; then
    echo "Error: One of --resolve or --unresolve is required." >&2
    usage >&2
    exit 1
  fi

  # Auto-detect PR number from current git branch if not provided
  if [[ -z "$number" ]]; then
    number=$(gh pr list --json number,headRefName \
      --jq ".[] | select(.headRefName == \"$(git branch --show-current)\") | .number" 2>/dev/null || echo "")
    if [[ -z "$number" ]]; then
      echo "Error: --number is required (could not auto-detect from current branch)." >&2
      usage >&2
      exit 1
    fi
  fi

  local owner repo
  owner=$(gh repo view --json owner --jq '.owner.login')
  repo=$(gh repo view --json name --jq '.name')

  local resolved_value
  if [[ "$action" == "resolve" ]]; then
    resolved_value="true"
  else
    resolved_value="false"
  fi

  gh api -X PATCH \
    "repos/${owner}/${repo}/pulls/${number}/threads/${thread_id}" \
    -f resolved="${resolved_value}" \
    --jq '{id: .id, resolved: .resolved}'

  echo "Thread ${thread_id} ${action}d successfully." >&2
}

main "$@"
