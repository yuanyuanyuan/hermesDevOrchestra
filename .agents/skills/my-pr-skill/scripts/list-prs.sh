#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: list-prs.sh [OPTIONS]

List PRs in the current repository.

Options:
  --state=STATE    Filter by state: open, closed, merged, all (default: open).
  --author=A       Filter by author login.
  --head=BRANCH    Filter by head branch name.
  --base=BRANCH    Filter by base branch name.
  --limit=N        Maximum number of PRs to fetch (default: 30).
  --json           Output JSON instead of tabular format.
  --output=FILE    Write output to FILE instead of stdout.
  --help           Show this message.

Requires: gh CLI authenticated; cwd inside a repo tracked by gh.
EOF
}

main() {
  local state="open"
  local author=""
  local head=""
  local base=""
  local limit="30"
  local json=""
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --state=*)   state="${1#*=}";   shift ;;
      --author=*)  author="${1#*=}";  shift ;;
      --head=*)    head="${1#*=}";    shift ;;
      --base=*)    base="${1#*=}";    shift ;;
      --limit=*)   limit="${1#*=}";   shift ;;
      --json)      json="1";          shift ;;
      --output=*)  output="${1#*=}";  shift ;;
      --help)      usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  local -a args=("--state=$state" "--limit=$limit")

  [[ -n "$author" ]] && args+=("--author=$author")
  [[ -n "$head"   ]] && args+=("--head=$head")
  [[ -n "$base"   ]] && args+=("--base=$base")

  local result
  if [[ -n "$json" ]]; then
    result=$(gh pr list "${args[@]}" \
      --json number,title,author,headRefName,baseRefName,state,createdAt,updatedAt,url,reviewDecision,isDraft)
  else
    result=$(gh pr list "${args[@]}")
  fi

  if [[ -n "$output" ]]; then
    mkdir -p "$(dirname "$output")"
    printf '%s\n' "$result" > "$output"
  else
    printf '%s\n' "$result"
  fi
}

main "$@"
