#!/usr/bin/env bash
# post-comment.sh — 向 PR 发送评论（Issue Comment API）
#
# Usage: post-comment.sh <PR_NUMBER> <BODY_FILE>
#   PR_NUMBER  — GitHub PR 编号
#   BODY_FILE  — Markdown 评论内容文件路径

set -euo pipefail

PR_NUMBER="${1:?Usage: post-comment.sh <PR_NUMBER> <BODY_FILE>}"
BODY_FILE="${2:?Missing body file}"

if [[ ! -f "$BODY_FILE" ]]; then
  echo "ERROR: Body file not found: $BODY_FILE" >&2
  exit 1
fi

BODY=$(cat "$BODY_FILE")
if [[ -z "$BODY" ]]; then
  echo "ERROR: Body file is empty" >&2
  exit 1
fi

OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

gh api "repos/${OWNER}/${REPO}/issues/${PR_NUMBER}/comments" \
  --method POST \
  --field body="$BODY" \
  --jq '.html_url'
