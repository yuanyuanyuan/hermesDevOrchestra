#!/usr/bin/env bash
# checkout-branch.sh — 安全 checkout PR 分支（Feature Branch 模式）
#
# 1. 保存当前分支名
# 2. 如有未提交更改则自动 stash
# 3. fetch 并 checkout PR 分支
# 4. 输出 JSON 状态供下游消费
#
# Usage: checkout-branch.sh <PR_NUMBER> [BRANCH]
#   BRANCH — 可选，PR 分支名。由 MCP 获取后传入时可跳过 gh pr view 查询。

set -euo pipefail

PR_NUMBER="${1:?Usage: checkout-branch.sh <PR_NUMBER>}"

ORIGINAL_BRANCH=$(git branch --show-current)
STASHED="false"

# ── 保存原分支名 ──
echo "$ORIGINAL_BRANCH" > "/tmp/pr-response-${PR_NUMBER}-original-branch"

# ── 处理未提交更改 ──
if ! git diff --quiet HEAD || ! git diff --cached --quiet HEAD; then
  git stash push -m "auto-stash-before-pr-${PR_NUMBER}" >/dev/null
  STASHED="true"
  echo "true" > "/tmp/pr-response-${PR_NUMBER}-stashed"
else
  echo "false" > "/tmp/pr-response-${PR_NUMBER}-stashed"
fi

# ── 获取并 checkout PR 分支 ──
if [[ $# -ge 2 && -n "$2" ]]; then
  BRANCH="$2"
else
  BRANCH=$(gh pr view "$PR_NUMBER" --json headRefName --jq '.headRefName')
fi
git fetch origin "$BRANCH"
git checkout "$BRANCH"

# ── 输出 JSON ──
jq -n \
  --arg branch "$BRANCH" \
  --arg originalBranch "$ORIGINAL_BRANCH" \
  --arg stashed "$STASHED" \
  '{
    branch: $branch,
    original_branch: $originalBranch,
    stashed: ($stashed == "true")
  }'

echo "Checked out branch: $BRANCH (from $ORIGINAL_BRANCH, stashed=$STASHED)" >&2
