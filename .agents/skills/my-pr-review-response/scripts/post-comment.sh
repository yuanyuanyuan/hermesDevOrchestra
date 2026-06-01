#!/usr/bin/env bash
# post-comment.sh — 向 PR 发送评论（Issue Comment API）
#
# MCP FALLBACK: 当 SKILL.md 中 GitHub MCP 路径不可用时，调用此脚本作为降级方案。
# 优先使用 mcp__github__add_issue_comment。
# 此脚本依赖 gh CLI 发送评论。
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
