#!/usr/bin/env bash
# checkout-branch.sh — fetch 并 checkout PR 分支
#
# Usage: checkout-branch.sh <PR_NUMBER>

set -euo pipefail

PR_NUMBER="${1:?Usage: checkout-branch.sh <PR_NUMBER>}"

BRANCH=$(gh pr view "$PR_NUMBER" --json headRefName --jq '.headRefName')

git fetch origin "$BRANCH"
git checkout "$BRANCH"

echo "Checked out branch: $BRANCH"
