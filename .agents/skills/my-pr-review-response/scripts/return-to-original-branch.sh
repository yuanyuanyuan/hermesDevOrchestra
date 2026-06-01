#!/usr/bin/env bash
# return-to-original-branch.sh — 恢复到 checkout 前的工作上下文（Feature Branch 模式）
#
# 1. 读取保存的原分支名
# 2. checkout 回原分支
# 3. 如有自动 stash 则 pop
# 4. 清理临时标记文件
#
# Usage: return-to-original-branch.sh <PR_NUMBER>

set -euo pipefail

PR_NUMBER="${1:?Usage: return-to-original-branch.sh <PR_NUMBER>}"

BRANCH_FILE="/tmp/pr-response-${PR_NUMBER}-original-branch"
STASHED_FILE="/tmp/pr-response-${PR_NUMBER}-stashed"

# ── 读取原分支 ──
if [[ ! -f "$BRANCH_FILE" ]]; then
  echo "WARN: No original branch snapshot found for PR #${PR_NUMBER}" >&2
  exit 0
fi

ORIGINAL_BRANCH=$(cat "$BRANCH_FILE")

# ── checkout 回原分支 ──
git checkout "$ORIGINAL_BRANCH"

# ── 恢复 stash（如有）──
if [[ -f "$STASHED_FILE" && "$(cat "$STASHED_FILE")" == "true" ]]; then
  git stash pop
fi

# ── 清理临时文件 ──
rm -f "$BRANCH_FILE" "$STASHED_FILE"

echo "Restored branch: $ORIGINAL_BRANCH" >&2
