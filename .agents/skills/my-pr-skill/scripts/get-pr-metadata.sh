#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: get-pr-metadata.sh --number=N [OPTIONS]

Fetch metadata for a GitHub PR.

Options:
  --number=N    PR number (required).
  --field=F     Print only a specific field (e.g., url, headRefName, headRefOid, reviewDecision).
  --output=FILE Write full JSON to FILE instead of stdout.
  --help        Show this message.

Requires: gh CLI authenticated; cwd inside a repo tracked by gh.
EOF
}

main() {
  local number=""
  local field=""
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --number=*) number="${1#*=}"; shift ;;
      --field=*)  field="${1#*=}";  shift ;;
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

  if [[ -n "$field" ]]; then
    gh pr view "$number" --json "$field" --jq ".$field"
    return 0
  fi

  local json
  json=$(gh pr view "$number" \
    --json number,title,body,author,headRefName,baseRefName,createdAt,updatedAt,mergeable,mergeStateStatus,changedFiles,additions,deletions,url,headRefOid,reviewDecision)

  if [[ -n "$output" ]]; then
    mkdir -p "$(dirname "$output")"
    printf '%s\n' "$json" > "$output"
  else
    printf '%s\n' "$json"
  fi
}

main "$@"
