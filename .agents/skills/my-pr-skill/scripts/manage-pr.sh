#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: manage-pr.sh { --create | --edit | --checks } [OPTIONS]

Manage a GitHub PR: create, edit labels, or check status.

Create mode:
  --create                 Create a new PR.
  --title=TITLE            PR title (required for create).
  --body-file=FILE         PR body from FILE (required for create).
  --base=BRANCH            Target branch (default: main).
  --head=BRANCH            Source branch (required for create).
  --repo=OWNER/REPO        Override repo (default: detected from cwd).

Edit mode:
  --edit                   Edit an existing PR.
  --number=N               PR number (required for edit).
  --add-label=LABEL        Add a label.

Checks mode:
  --checks                 Print combined status / checks for a PR.
  --number=N               PR number (required for checks).

Common:
  --help                   Show this message.

Requires: gh CLI authenticated.
EOF
}

main() {
  local mode=""
  local number=""
  local title=""
  local body_file=""
  local base="main"
  local head=""
  local repo=""
  local add_label=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --create)     mode="create"; shift ;;
      --edit)       mode="edit";   shift ;;
      --checks)     mode="checks"; shift ;;
      --number=*)   number="${1#*=}"; shift ;;
      --title=*)    title="${1#*=}";  shift ;;
      --body-file=*) body_file="${1#*=}"; shift ;;
      --base=*)     base="${1#*=}";   shift ;;
      --head=*)     head="${1#*=}";   shift ;;
      --repo=*)     repo="${1#*=}";   shift ;;
      --add-label=*) add_label="${1#*=}"; shift ;;
      --help)       usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
  done

  if [[ -z "$mode" ]]; then
    echo "Error: one of --create, --edit, or --checks is required." >&2
    usage >&2
    exit 1
  fi

  local owner detected_repo
  owner=$(gh repo view --json owner --jq '.owner.login')
  detected_repo=$(gh repo view --json name --jq '.name')
  repo="${repo:-${owner}/${detected_repo}}"

  case "$mode" in
    create)
      if [[ -z "$title" || -z "$body_file" || -z "$head" ]]; then
        echo "Error: --title, --body-file, and --head are required for --create." >&2
        usage >&2
        exit 1
      fi
      gh pr create \
        --title "$title" \
        --body-file "$body_file" \
        --base "$base" \
        --head "$head" \
        --repo "$repo" 2>/dev/null || echo "PR may already exist"
      ;;
    edit)
      if [[ -z "$number" ]]; then
        echo "Error: --number is required for --edit." >&2
        usage >&2
        exit 1
      fi
      if [[ -n "$add_label" ]]; then
        gh pr edit "$number" --add-label "$add_label"
      fi
      ;;
    checks)
      if [[ -z "$number" ]]; then
        echo "Error: --number is required for --checks." >&2
        usage >&2
        exit 1
      fi
      gh pr checks "$number" 2>/dev/null || true
      ;;
  esac
}

main "$@"
