#!/usr/bin/env bash
# diff-since.sh — Detect files changed between a base commit and current PR head
#
# Used for re-review: only re-check files that changed since last review.
#
# Usage: diff-since.sh <PR_NUMBER> <LAST_REVIEWED_OID>
# Outputs JSON: {files: [...], scope: "full"|"partial", reason: "..."}

set -euo pipefail

PR_NUMBER="${1:?Usage: diff-since.sh <PR_NUMBER> <LAST_REVIEWED_OID>}"
LAST_REVIEWED_OID="${2:?Missing last reviewed commit OID}"

# Get current PR head
HEAD_OID=$(gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid')

if [[ "$HEAD_OID" == "$LAST_REVIEWED_OID" ]]; then
  jq -n '{files: [], scope: "none", reason: "No new commits since last review"}'
  exit 0
fi

# Get changed files between last review and current head
CHANGED_FILES=$(git diff --name-only "$LAST_REVIEWED_OID".."$HEAD_OID" 2>/dev/null || echo "")

if [[ -z "$CHANGED_FILES" ]]; then
  # Fallback: try fetching from remote
  git fetch origin 2>/dev/null || true
  CHANGED_FILES=$(git diff --name-only "$LAST_REVIEWED_OID".."$HEAD_OID" 2>/dev/null || echo "")
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | grep -c '.' || echo "0")

if [[ "$FILE_COUNT" -eq 0 ]]; then
  jq -n '{files: [], scope: "none", reason: "No file changes detected between commits"}'
elif [[ "$FILE_COUNT" -gt 20 ]]; then
  # Too many files changed — full review recommended
  echo "$CHANGED_FILES" | jq -R -s '{
    files: (split("\n") | map(select(length > 0))),
    scope: "full",
    reason: "More than 20 files changed, full review recommended"
  }'
else
  echo "$CHANGED_FILES" | jq -R -s '{
    files: (split("\n") | map(select(length > 0))),
    scope: "partial",
    reason: "Only changed files need re-review"
  }'
fi
